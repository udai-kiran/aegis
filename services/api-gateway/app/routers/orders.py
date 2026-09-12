"""Order list and detail endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.database import get_db
from app.models import Order, User
from app.schemas import OrderResponse

router = APIRouter(prefix="/tenants/{tenant_id}/orders", tags=["orders"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.get("", response_model=list[OrderResponse])
def list_orders(
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID | None = None,
    symbol: str | None = None,
    order_status: str | None = Query(default=None, alias="status"),
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
    """List orders for a tenant, optionally filtered by portfolio, status, or symbol."""
    _check_tenant_access(tenant_id, current_user)

    query = db.query(Order).filter(Order.tenant_id == tenant_id)
    if portfolio_id is not None:
        query = query.filter(Order.portfolio_id == portfolio_id)
    if order_status is not None:
        query = query.filter(Order.status == order_status)

    if symbol is not None:
        query = query.filter(Order.symbol == symbol)
    return query.order_by(Order.created_at.desc()).all()


@router.get("/{order_id}", response_model=OrderResponse)
def get_order(
    tenant_id: uuid.UUID,
    order_id: uuid.UUID,
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
    """Get a single order."""
    _check_tenant_access(tenant_id, current_user)

    order = (
        db.query(Order)
        .filter(Order.id == order_id, Order.tenant_id == tenant_id)
        .first()
    )
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Order not found"
        )
    return order
