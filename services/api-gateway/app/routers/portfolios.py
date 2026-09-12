"""Portfolio management endpoints (tenant-scoped)."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import BacktestRun, Portfolio, StrategyConfig, Tenant, User
from app.schemas import PortfolioCreate, PortfolioResponse, PortfolioUpdate

router = APIRouter(prefix="/tenants/{tenant_id}/portfolios", tags=["portfolios"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")


@router.get("", response_model=list[PortfolioResponse])
def list_portfolios(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER", "RISK_MANAGER", "VIEWER")),
):
    """List all portfolios for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return db.query(Portfolio).filter(Portfolio.tenant_id == tenant_id).order_by(Portfolio.created_at).all()


@router.post("", response_model=PortfolioResponse, status_code=status.HTTP_201_CREATED)
def create_portfolio(
    tenant_id: uuid.UUID,
    body: PortfolioCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Create a portfolio within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found")

    portfolio = Portfolio(
        tenant_id=tenant_id,
        name=body.name,
        starting_capital=body.starting_capital,
        current_equity=body.starting_capital,
        cash=body.starting_capital,
        trading_mode=body.trading_mode,
    )
    db.add(portfolio)
    db.flush()

    record_audit(
        db,
        action="portfolio_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"portfolio:{portfolio.id}",
        after_state=body.model_dump(),
    )
    db.commit()
    db.refresh(portfolio)
    return portfolio


@router.get("/{portfolio_id}", response_model=PortfolioResponse)
def get_portfolio(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER", "RISK_MANAGER", "VIEWER")),
):
    """Get a single portfolio."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = db.query(Portfolio).filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id).first()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")
    return portfolio


@router.patch("/{portfolio_id}", response_model=PortfolioResponse)
def update_portfolio(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    body: PortfolioUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Update a portfolio."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = db.query(Portfolio).filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id).first()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

    before = {"name": portfolio.name, "trading_mode": portfolio.trading_mode}
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(portfolio, key, value)
    db.flush()

    record_audit(
        db,
        action="portfolio_updated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"portfolio:{portfolio_id}",
        before_state=before,
        after_state=updates,
    )
    db.commit()
    db.refresh(portfolio)
    return portfolio


@router.delete("/{portfolio_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_portfolio(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Delete a portfolio."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = db.query(Portfolio).filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id).first()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

    has_configs = (
        db.query(StrategyConfig)
        .filter(StrategyConfig.portfolio_id == portfolio_id, StrategyConfig.tenant_id == tenant_id)
        .first()
    )
    if has_configs:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete portfolio with active strategy configurations",
        )

    has_runs = (
        db.query(BacktestRun)
        .filter(BacktestRun.portfolio_id == portfolio_id, BacktestRun.tenant_id == tenant_id)
        .first()
    )
    if has_runs:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete portfolio with existing backtest runs",
        )

    record_audit(
        db,
        action="portfolio_deleted",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"portfolio:{portfolio_id}",
        before_state={"name": portfolio.name, "trading_mode": portfolio.trading_mode},
    )
    db.delete(portfolio)
    db.commit()
