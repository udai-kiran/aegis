"""Strategy and strategy config endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import Portfolio, Strategy, StrategyConfig, User
from app.schemas import (
    StrategyConfigCreate,
    StrategyConfigResponse,
    StrategyConfigUpdate,
    StrategyCreate,
    StrategyResponse,
    StrategyUpdate,
)

router = APIRouter(prefix="/tenants/{tenant_id}/strategies", tags=["strategies"])
config_router = APIRouter(
    prefix="/tenants/{tenant_id}/strategy-configs", tags=["strategy-configs"]
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


def _get_accessible_strategy(
    db: Session, tenant_id: uuid.UUID, strategy_id: uuid.UUID
) -> Strategy | None:
    """Return the strategy if it belongs to the tenant or is a platform strategy."""
    return (
        db.query(Strategy)
        .filter(
            Strategy.id == strategy_id,
            (Strategy.tenant_id == tenant_id) | (Strategy.tenant_id.is_(None)),
        )
        .first()
    )


@router.get("", response_model=list[StrategyResponse])
def list_strategies(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(
            "PLATFORM_ADMIN",
            "TENANT_ADMIN",
            "TRADER",
            "RESEARCHER",
            "RISK_MANAGER",
            "VIEWER",
        )
    ),
):
    """List strategies visible to the tenant (tenant-owned plus platform strategies)."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(Strategy)
        .filter((Strategy.tenant_id == tenant_id) | (Strategy.tenant_id.is_(None)))
        .order_by(Strategy.created_at)
        .all()
    )


@router.post("", response_model=StrategyResponse, status_code=status.HTTP_201_CREATED)
def create_strategy(
    tenant_id: uuid.UUID,
    body: StrategyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Create a strategy within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    existing = (
        db.query(Strategy)
        .filter(
            Strategy.tenant_id == tenant_id,
            Strategy.name == body.name,
            Strategy.version == body.version,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Strategy with this name and version already exists",
        )

    strategy = Strategy(
        tenant_id=tenant_id,
        name=body.name,
        version=body.version,
        strategy_type=body.strategy_type,
        description=body.description,
    )
    db.add(strategy)
    db.flush()

    record_audit(
        db,
        action="strategy_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy:{strategy.id}",
        after_state=body.model_dump(),
    )
    db.commit()
    db.refresh(strategy)
    return strategy


@router.get("/{strategy_id}", response_model=StrategyResponse)
def get_strategy(
    tenant_id: uuid.UUID,
    strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(
            "PLATFORM_ADMIN",
            "TENANT_ADMIN",
            "TRADER",
            "RESEARCHER",
            "RISK_MANAGER",
            "VIEWER",
        )
    ),
):
    """Get a single strategy (tenant-owned or platform)."""
    _check_tenant_access(tenant_id, current_user)

    strategy = _get_accessible_strategy(db, tenant_id, strategy_id)
    if not strategy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Strategy not found"
        )
    return strategy


@router.patch("/{strategy_id}", response_model=StrategyResponse)
def update_strategy(
    tenant_id: uuid.UUID,
    strategy_id: uuid.UUID,
    body: StrategyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Update a strategy."""
    _check_tenant_access(tenant_id, current_user)

    strategy = _get_accessible_strategy(db, tenant_id, strategy_id)
    if not strategy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Strategy not found"
        )
    if strategy.tenant_id is None and current_user.role != "PLATFORM_ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform strategies can only be updated by platform admins",
        )

    before = {"description": strategy.description, "is_active": strategy.is_active}
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(strategy, key, value)
    db.flush()

    record_audit(
        db,
        action="strategy_updated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy:{strategy_id}",
        before_state=before,
        after_state=updates,
    )
    db.commit()
    db.refresh(strategy)
    return strategy


@config_router.post(
    "", response_model=StrategyConfigResponse, status_code=status.HTTP_201_CREATED
)
def create_strategy_config(
    tenant_id: uuid.UUID,
    body: StrategyConfigCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Create a strategy config within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    strategy = _get_accessible_strategy(db, tenant_id, body.strategy_id)
    if not strategy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Strategy not found"
        )

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )

    config = StrategyConfig(
        tenant_id=tenant_id,
        strategy_id=body.strategy_id,
        portfolio_id=body.portfolio_id,
        parameters=body.parameters,
    )
    db.add(config)
    db.flush()

    record_audit(
        db,
        action="strategy_config_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy_config:{config.id}",
        after_state=body.model_dump(mode="json"),
    )
    db.commit()
    db.refresh(config)
    return config


@config_router.get("", response_model=list[StrategyConfigResponse])
def list_strategy_configs(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(
            "PLATFORM_ADMIN",
            "TENANT_ADMIN",
            "TRADER",
            "RESEARCHER",
            "RISK_MANAGER",
            "VIEWER",
        )
    ),
):
    """List strategy configs for a tenant, optionally filtered by portfolio."""
    _check_tenant_access(tenant_id, current_user)

    query = db.query(StrategyConfig).filter(StrategyConfig.tenant_id == tenant_id)
    if portfolio_id is not None:
        query = query.filter(StrategyConfig.portfolio_id == portfolio_id)
    return query.order_by(StrategyConfig.created_at).all()


@config_router.patch("/{config_id}", response_model=StrategyConfigResponse)
def update_strategy_config(
    tenant_id: uuid.UUID,
    config_id: uuid.UUID,
    body: StrategyConfigUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Update a strategy config."""
    _check_tenant_access(tenant_id, current_user)

    config = (
        db.query(StrategyConfig)
        .filter(StrategyConfig.id == config_id, StrategyConfig.tenant_id == tenant_id)
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Strategy config not found"
        )

    before = {
        "parameters": config.parameters,
        "lifecycle_status": config.lifecycle_status,
    }
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(config, key, value)
    db.flush()

    record_audit(
        db,
        action="strategy_config_updated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy_config:{config_id}",
        before_state=before,
        after_state=updates,
    )
    db.commit()
    db.refresh(config)
    return config
