"""Execution endpoints: submit orders through broker accounts and reconcile."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.execution.engine import ExecutionEngine
from app.execution.reconciliation import ReconciliationEngine
from app.models import BrokerAccount, Order, User
from app.schemas import (
    ExecutionRequest,
    OrderResponse,
    ReconciliationResult,
)

router = APIRouter(prefix="/tenants/{tenant_id}/execution", tags=["execution"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post(
    "/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED
)
def submit_execution_order(
    tenant_id: uuid.UUID,
    body: ExecutionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER")
    ),
):
    """Submit an order for execution through a broker account."""
    _check_tenant_access(tenant_id, current_user)

    if body.price is not None and body.price <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Price must be positive",
        )

    try:
        order = ExecutionEngine(db).execute(
            tenant_id,
            body.portfolio_id,
            body.broker_account_id,
            body.symbol,
            body.exchange,
            body.side,
            body.order_type,
            body.quantity,
            body.price,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc

    record_audit(
        db,
        action="execution_order_submitted",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"order:{order.id}",
        after_state={
            "symbol": body.symbol,
            "side": body.side,
            "quantity": body.quantity,
            "status": order.status,
            "broker_account_id": str(body.broker_account_id),
        },
    )
    db.commit()
    db.refresh(order)
    return order


@router.get("/orders", response_model=list[OrderResponse])
def list_execution_orders(
    tenant_id: uuid.UUID,
    broker_account_id: uuid.UUID | None = None,
    order_status: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(
            "PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RISK_MANAGER", "VIEWER"
        )
    ),
):
    """List execution (non-paper) orders for a tenant, optionally filtered."""
    _check_tenant_access(tenant_id, current_user)

    query = db.query(Order).filter(
        Order.tenant_id == tenant_id, Order.source != "PAPER"
    )
    if broker_account_id is not None:
        query = query.filter(Order.broker_account_id == broker_account_id)
    if order_status is not None:
        query = query.filter(Order.status == order_status)
    return query.order_by(Order.created_at.desc()).all()


@router.post("/reconcile/{account_id}", response_model=ReconciliationResult)
def reconcile_broker_account(
    tenant_id: uuid.UUID,
    account_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Reconcile internal positions against broker-reported positions."""
    _check_tenant_access(tenant_id, current_user)

    account = (
        db.query(BrokerAccount)
        .filter(BrokerAccount.id == account_id, BrokerAccount.tenant_id == tenant_id)
        .first()
    )
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Broker account not found"
        )

    try:
        result = ReconciliationEngine(db).reconcile(tenant_id, account_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc

    record_audit(
        db,
        action="reconciliation_completed",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"broker_account:{account_id}",
        after_state={"status": result["status"]},
    )
    db.commit()
    return result
