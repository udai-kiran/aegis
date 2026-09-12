"""Backtest run endpoints (tenant-scoped)."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.backtest.scheduler import backtest_scheduler
from app.database import get_db
from app.models import BacktestRun, StrategyConfig, User
from app.schemas import BacktestCreate, BacktestResponse

router = APIRouter(prefix="/tenants/{tenant_id}/backtests", tags=["backtests"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")


@router.post("", response_model=BacktestResponse, status_code=status.HTTP_201_CREATED)
def submit_backtest(
    tenant_id: uuid.UUID,
    body: BacktestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")),
):
    """Submit a backtest run for a strategy config owned by the tenant."""
    _check_tenant_access(tenant_id, current_user)

    config = (
        db.query(StrategyConfig)
        .filter(StrategyConfig.id == body.strategy_config_id, StrategyConfig.tenant_id == tenant_id)
        .first()
    )
    if not config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Strategy config not found")

    if body.start_date >= body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before end_date",
        )

    run = BacktestRun(
        tenant_id=tenant_id,
        portfolio_id=config.portfolio_id,
        strategy_config_id=body.strategy_config_id,
        symbol=body.symbol,
        exchange=body.exchange,
        timeframe=body.timeframe,
        start_date=body.start_date,
        end_date=body.end_date,
        parameters=body.parameters,
        status="PENDING",
    )
    db.add(run)
    db.flush()

    record_audit(
        db,
        action="backtest_submitted",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"backtest:{run.id}",
        after_state=body.model_dump(mode="json"),
    )
    db.commit()

    if not backtest_scheduler.submit(run.id):
        run.status = "FAILED"
        run.error_message = "Tenant backtest quota exceeded"
        db.commit()

    return run


@router.get("", response_model=list[BacktestResponse])
def list_backtests(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID | None = Query(default=None),
    backtest_status: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER", "RISK_MANAGER", "VIEWER")),
):
    """List backtest runs for a tenant, optionally filtered by portfolio or status."""
    _check_tenant_access(tenant_id, current_user)

    query = db.query(BacktestRun).filter(BacktestRun.tenant_id == tenant_id)
    if portfolio_id is not None:
        query = query.filter(BacktestRun.portfolio_id == portfolio_id)
    if backtest_status is not None:
        query = query.filter(BacktestRun.status == backtest_status)
    return query.order_by(BacktestRun.created_at.desc()).all()


@router.get("/{backtest_id}", response_model=BacktestResponse)
def get_backtest(
    tenant_id: uuid.UUID,
    backtest_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER", "RISK_MANAGER", "VIEWER")),
):
    """Get a single backtest run belonging to the tenant."""
    _check_tenant_access(tenant_id, current_user)

    run = (
        db.query(BacktestRun)
        .filter(BacktestRun.id == backtest_id, BacktestRun.tenant_id == tenant_id)
        .first()
    )
    if not run:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Backtest not found")
    return run
