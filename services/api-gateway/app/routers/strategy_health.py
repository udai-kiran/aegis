"""Strategy health scoring endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import StrategyHealthScore, User
from app.schemas import HealthEvaluateRequest, StrategyHealthResponse

router = APIRouter(
    prefix="/tenants/{tenant_id}/strategy-health", tags=["strategy-health"]
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post(
    "/evaluate",
    response_model=StrategyHealthResponse,
    status_code=status.HTTP_201_CREATED,
)
def evaluate_health(
    tenant_id: uuid.UUID,
    body: HealthEvaluateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Evaluate and store health score for a strategy config."""
    _check_tenant_access(tenant_id, current_user)

    from app.models import Portfolio, StrategyConfig

    config = (
        db.query(StrategyConfig)
        .filter(
            StrategyConfig.id == body.strategy_config_id,
            StrategyConfig.tenant_id == tenant_id,
        )
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Strategy config not found",
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
    if config.portfolio_id != body.portfolio_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Strategy config does not belong to specified portfolio",
        )

    from app.intelligence.health import evaluate_health as _evaluate

    result = _evaluate(db, tenant_id, body.strategy_config_id, body.portfolio_id)

    health = StrategyHealthScore(
        tenant_id=tenant_id,
        strategy_config_id=body.strategy_config_id,
        portfolio_id=body.portfolio_id,
        win_rate=result["win_rate"],
        avg_return=result["avg_return"],
        sharpe_ratio=result["sharpe_ratio"],
        max_drawdown=result["max_drawdown"],
        total_trades=result["total_trades"],
        recent_pnl=result["recent_pnl"],
        health_score=result["health_score"],
        health_status=result["health_status"],
    )
    db.add(health)
    db.flush()

    record_audit(
        db,
        action="strategy_health_evaluated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"strategy_health:{health.id}",
        after_state={
            "health_score": result["health_score"],
            "health_status": result["health_status"],
        },
    )
    db.commit()
    db.refresh(health)
    return health


@router.get("", response_model=list[StrategyHealthResponse])
def list_health_scores(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List all strategy health scores for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(StrategyHealthScore)
        .filter(StrategyHealthScore.tenant_id == tenant_id)
        .order_by(StrategyHealthScore.evaluated_at.desc())
        .all()
    )


@router.get("/{health_id}", response_model=StrategyHealthResponse)
def get_health_score(
    tenant_id: uuid.UUID,
    health_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """Get a single health score by ID."""
    _check_tenant_access(tenant_id, current_user)
    health = (
        db.query(StrategyHealthScore)
        .filter(
            StrategyHealthScore.id == health_id,
            StrategyHealthScore.tenant_id == tenant_id,
        )
        .first()
    )
    if not health:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Health score not found"
        )
    return health
