"""Position query endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.database import get_db
from app.models import Portfolio, Position, User
from app.schemas import PositionResponse

router = APIRouter(
    prefix="/tenants/{tenant_id}/portfolios/{portfolio_id}/positions",
    tags=["positions"],
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


def _get_portfolio(
    db: Session, tenant_id: uuid.UUID, portfolio_id: uuid.UUID
) -> Portfolio:
    """Return the portfolio or raise 404 if it does not belong to the tenant."""
    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )
    return portfolio


@router.get("", response_model=list[PositionResponse])
def list_positions(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    symbol: str | None = None,
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
    """List positions for a portfolio, optionally filtered by symbol."""
    _check_tenant_access(tenant_id, current_user)
    _get_portfolio(db, tenant_id, portfolio_id)

    query = db.query(Position).filter(
        Position.tenant_id == tenant_id,
        Position.portfolio_id == portfolio_id,
    )
    if symbol is not None:
        query = query.filter(Position.symbol == symbol)
    return query.order_by(Position.symbol).all()


@router.get("/{position_id}", response_model=PositionResponse)
def get_position(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    position_id: uuid.UUID,
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
    """Get a single position."""
    _check_tenant_access(tenant_id, current_user)

    position = (
        db.query(Position)
        .filter(
            Position.id == position_id,
            Position.tenant_id == tenant_id,
            Position.portfolio_id == portfolio_id,
        )
        .first()
    )
    if not position:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Position not found"
        )
    return position
