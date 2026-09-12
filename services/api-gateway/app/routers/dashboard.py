"""Portfolio dashboard endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.database import get_db
from app.models import Order, Portfolio, Position, User
from app.risk import RiskEvaluator
from app.schemas import PortfolioDashboard

router = APIRouter(prefix="/tenants/{tenant_id}/dashboard", tags=["dashboard"])

OPEN_ORDER_STATUSES = ("NEW", "SUBMITTED", "ACKNOWLEDGED", "PARTIALLY_FILLED")


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.get("/{portfolio_id}", response_model=PortfolioDashboard)
def get_portfolio_dashboard(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
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
    """Get the dashboard summary for a single portfolio."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )

    positions = (
        db.query(Position)
        .filter(
            Position.portfolio_id == portfolio_id,
            Position.tenant_id == tenant_id,
        )
        .all()
    )
    total_pnl = float(portfolio.current_equity) - float(portfolio.starting_capital)
    daily_pnl = sum(
        float(p.unrealized_pnl) if p.unrealized_pnl is not None else 0.0
        for p in positions
    )

    open_orders_count = (
        db.query(Order)
        .filter(
            Order.portfolio_id == portfolio_id,
            Order.tenant_id == tenant_id,
            Order.status.in_(OPEN_ORDER_STATUSES),
        )
        .count()
    )

    risk_status = RiskEvaluator(db).get_portfolio_risk_status(tenant_id, portfolio_id)

    return PortfolioDashboard(
        portfolio_id=portfolio.id,
        portfolio_name=portfolio.name,
        trading_mode=portfolio.trading_mode,
        starting_capital=float(portfolio.starting_capital),
        current_equity=float(portfolio.current_equity),
        cash=float(portfolio.cash),
        total_pnl=total_pnl,
        daily_pnl=daily_pnl,
        positions_count=len(positions),
        open_orders_count=open_orders_count,
        risk_status=risk_status.value,
    )
