"""Paper trading order endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.broker.base import OrderRequest
from app.broker.paper import PaperBroker
from app.database import get_db
from app.models import Order, Portfolio, Position, User
from app.risk import RiskEvaluator
from app.schemas import OrderCreate, OrderResponse

router = APIRouter(prefix="/tenants/{tenant_id}/paper-orders", tags=["paper-trading"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


def _risk_decision_dict(approved: bool, decision) -> dict:
    return {
        "approved": approved,
        "reason": decision.reason,
        "status": decision.status.value,
        "approved_quantity": decision.approved_quantity if approved else None,
    }


def _apply_fill(
    db: Session,
    portfolio: Portfolio,
    side: str,
    symbol: str,
    exchange: str,
    filled_quantity: float,
    avg_fill_price: float,
) -> None:
    """Update or create the position for this fill and adjust portfolio cash/equity."""
    position = (
        db.query(Position)
        .filter(
            Position.portfolio_id == portfolio.id,
            Position.tenant_id == portfolio.tenant_id,
            Position.symbol == symbol,
            Position.exchange == exchange,
        )
        .first()
    )

    if position is not None:
        if side == "BUY":
            new_qty = float(position.quantity) + filled_quantity
            if new_qty > 0:
                position.avg_entry_price = (
                    float(position.avg_entry_price) * float(position.quantity)
                    + avg_fill_price * filled_quantity
                ) / new_qty
                position.quantity = new_qty
        else:  # SELL
            new_qty = float(position.quantity) - filled_quantity
            if new_qty <= 0:
                position.realized_pnl = float(position.realized_pnl) + filled_quantity * (
                    avg_fill_price - float(position.avg_entry_price)
                )
                db.delete(position)
                position = None
            else:
                position.realized_pnl = float(position.realized_pnl) + filled_quantity * (
                    avg_fill_price - float(position.avg_entry_price)
                )
                position.quantity = new_qty

        if position is not None:
            position.current_price = avg_fill_price
    elif side == "BUY":
        position = Position(
            tenant_id=portfolio.tenant_id,
            portfolio_id=portfolio.id,
            symbol=symbol,
            exchange=exchange,
            quantity=filled_quantity,
            avg_entry_price=avg_fill_price,
            current_price=avg_fill_price,
        )
        db.add(position)

    trade_value = filled_quantity * avg_fill_price
    if side == "BUY":
        portfolio.cash = float(portfolio.cash) - trade_value
    else:
        portfolio.cash = float(portfolio.cash) + trade_value

    db.flush()

    positions = (
        db.query(Position)
        .filter(
            Position.portfolio_id == portfolio.id,
            Position.tenant_id == portfolio.tenant_id,
        )
        .all()
    )
    positions_value = sum(
        float(p.quantity) * float(p.current_price)
        for p in positions
        if p.current_price is not None
    )
    portfolio.current_equity = float(portfolio.cash) + positions_value


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def submit_paper_order(
    tenant_id: uuid.UUID,
    body: OrderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER")
    ),
):
    """Submit a paper order: risk check, simulated fill, position and cash update."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )

    if portfolio.trading_mode != "PAPER":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Portfolio is not in PAPER trading mode",
        )

    if body.price is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Price required for paper orders",
        )

    if body.price <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Price must be positive",
        )

    if body.side.upper() == "SELL":
        existing_position = (
            db.query(Position)
            .filter(
                Position.portfolio_id == body.portfolio_id,
                Position.tenant_id == tenant_id,
                Position.symbol == body.symbol,
                Position.exchange == body.exchange,
            )
            .first()
        )
        held_qty = float(existing_position.quantity) if existing_position else 0.0
        if held_qty <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No position to sell",
            )
        if body.quantity > held_qty:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot sell {body.quantity} — only {held_qty} held",
            )

    evaluator = RiskEvaluator(db)
    decision = evaluator.evaluate_order(
        tenant_id,
        body.portfolio_id,
        body.symbol,
        body.side,
        body.quantity,
        body.price,
    )

    order = Order(
        tenant_id=tenant_id,
        portfolio_id=body.portfolio_id,
        symbol=body.symbol,
        exchange=body.exchange,
        side=body.side,
        order_type=body.order_type,
        quantity=body.quantity,
        price=body.price,
        status="REJECTED" if not decision.approved else "NEW",
        source="PAPER",
    )

    if not decision.approved:
        order.reject_reason = decision.reason
        order.risk_decision = _risk_decision_dict(False, decision)
    else:
        approved_quantity = decision.approved_quantity
        order.quantity = approved_quantity
        request = OrderRequest(
            tenant_id=tenant_id,
            portfolio_id=body.portfolio_id,
            symbol=body.symbol,
            side=body.side,
            quantity=approved_quantity,
            exchange=body.exchange,
            order_type=body.order_type,
            price=body.price,
        )
        result = PaperBroker(db).place_order(request)
        order.status = result.status
        order.filled_quantity = result.filled_quantity
        order.avg_fill_price = result.avg_fill_price
        order.reject_reason = result.reject_reason
        order.risk_decision = _risk_decision_dict(True, decision)

        if result.status == "FILLED":
            _apply_fill(
                db,
                portfolio,
                body.side,
                body.symbol,
                body.exchange,
                result.filled_quantity,
                result.avg_fill_price,
            )

    db.add(order)
    db.flush()

    record_audit(
        db,
        action="paper_order_submitted",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"order:{order.id}",
        after_state=order.risk_decision,
    )
    db.commit()
    db.refresh(order)
    return order
