"""Strategy configuration endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import Portfolio, Strategy, StrategyConfig, User
from app.schemas import (
    StrategyConfigCreate,
    StrategyConfigResponse,
    StrategyConfigUpdate,
)

router = APIRouter(
    prefix="/tenants/{tenant_id}/strategy-configs", tags=["strategy-configs"]
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.get("", response_model=list[StrategyConfigResponse])
def list_strategy_configs(
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
    """List strategy configs for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(StrategyConfig)
        .filter(StrategyConfig.tenant_id == tenant_id)
        .order_by(StrategyConfig.created_at)
        .all()
    )


@router.post(
    "", response_model=StrategyConfigResponse, status_code=status.HTTP_201_CREATED
)
def create_strategy_config(
    tenant_id: uuid.UUID,
    body: StrategyConfigCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER")
    ),
):
    """Create a strategy config within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    # Validate portfolio belongs to this tenant
    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Portfolio not found in this tenant",
        )

    # Validate strategy exists and is accessible
    strategy = db.query(Strategy).filter(Strategy.id == body.strategy_id).first()
    if not strategy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Strategy not found"
        )
    if strategy.owner_type == "TENANT" and strategy.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Strategy not accessible to this tenant",
        )

    config = StrategyConfig(
        tenant_id=tenant_id,
        portfolio_id=body.portfolio_id,
        strategy_id=body.strategy_id,
        parameters=body.parameters,
        lifecycle_status=body.lifecycle_status,
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


@router.get("/{config_id}", response_model=StrategyConfigResponse)
def get_strategy_config(
    tenant_id: uuid.UUID,
    config_id: uuid.UUID,
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
    """Get a single strategy config."""
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
    return config


@router.patch("/{config_id}", response_model=StrategyConfigResponse)
def update_strategy_config(
    tenant_id: uuid.UUID,
    config_id: uuid.UUID,
    body: StrategyConfigUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER")
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
        "is_active": config.is_active,
    }
    updates = body.model_dump(exclude_unset=True)
    for key in ("parameters", "lifecycle_status", "is_active"):
        if key in updates and updates[key] is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{key} cannot be set to null",
            )
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


@router.delete("/{config_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_strategy_config(
    tenant_id: uuid.UUID,
    config_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Delete a strategy config."""
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

    record_audit(
        db,
        action="strategy_config_deleted",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy_config:{config_id}",
        before_state={
            "parameters": config.parameters,
            "lifecycle_status": config.lifecycle_status,
            "is_active": config.is_active,
        },
    )
    try:
        db.delete(config)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete: strategy config has dependent resources (e.g., backtest runs)",
        )
