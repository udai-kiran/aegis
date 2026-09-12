"""Backtest run endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import BacktestRun, Portfolio, StrategyConfig, User
from app.schemas import BacktestRunCreate, BacktestRunResponse

router = APIRouter(prefix="/tenants/{tenant_id}/backtests", tags=["backtests"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.get("", response_model=list[BacktestRunResponse])
def list_backtests(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID | None = Query(default=None),
    backtest_status: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
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
    """List backtests for a tenant. Optional filters: portfolio_id, status."""
    _check_tenant_access(tenant_id, current_user)

    q = db.query(BacktestRun).filter(BacktestRun.tenant_id == tenant_id)
    if portfolio_id:
        q = q.filter(BacktestRun.portfolio_id == portfolio_id)
    if backtest_status:
        q = q.filter(BacktestRun.status == backtest_status)

    return q.order_by(BacktestRun.created_at.desc()).offset(offset).limit(limit).all()


@router.post(
    "", response_model=BacktestRunResponse, status_code=status.HTTP_201_CREATED
)
def create_backtest(
    tenant_id: uuid.UUID,
    body: BacktestRunCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER")
    ),
):
    """Create a new backtest run. Status starts as PENDING."""
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

    # Validate strategy config belongs to this tenant
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
            detail="Strategy config not found in this tenant",
        )

    if config.portfolio_id != body.portfolio_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="portfolio_id does not match strategy config's portfolio",
        )

    if body.start_date >= body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before end_date",
        )

    backtest = BacktestRun(
        tenant_id=tenant_id,
        portfolio_id=body.portfolio_id,
        strategy_config_id=body.strategy_config_id,
        start_date=body.start_date,
        end_date=body.end_date,
        timeframe=body.timeframe,
        parameters=body.parameters,
    )
    db.add(backtest)
    db.flush()

    record_audit(
        db,
        action="backtest_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"backtest:{backtest.id}",
        after_state=body.model_dump(mode="json"),
    )
    db.commit()
    db.refresh(backtest)
    return backtest


@router.get("/{backtest_id}", response_model=BacktestRunResponse)
def get_backtest(
    tenant_id: uuid.UUID,
    backtest_id: uuid.UUID,
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
    """Get a single backtest run with metrics."""
    _check_tenant_access(tenant_id, current_user)

    backtest = (
        db.query(BacktestRun)
        .filter(BacktestRun.id == backtest_id, BacktestRun.tenant_id == tenant_id)
        .first()
    )
    if not backtest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Backtest not found"
        )
    return backtest
