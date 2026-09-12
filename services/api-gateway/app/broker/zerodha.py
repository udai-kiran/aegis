"""Zerodha broker adapter (stub for MVP)."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.broker.base import Broker, OrderRequest, OrderResult

logger = logging.getLogger(__name__)


class ZerodhaBroker(Broker):
    """Stub Zerodha adapter that simulates fills for development/testing.

    In production, this would use the kiteconnect Python SDK.

    Args:
        db: SQLAlchemy session used for position lookups.
        credentials: Zerodha API credentials (api_key, access_token, etc.).
    """

    def __init__(self, db: Session, credentials: dict | None = None) -> None:
        self.db = db
        self.credentials = credentials

    def place_order(self, request: OrderRequest) -> OrderResult:
        if self.credentials is None:
            logger.warning(
                "Zerodha stub: order rejected: %s %s — no broker credentials",
                request.side,
                request.symbol,
            )
            return OrderResult(
                order_id=uuid.uuid4(),
                status="REJECTED",
                filled_quantity=0.0,
                avg_fill_price=0.0,
                reject_reason="No broker credentials configured",
                timestamp=datetime.now(timezone.utc),
            )

        # MVP stub: simulate a fill like PaperBroker with 0.05% slippage
        price = request.price or 0.0
        adjustment = 0.0005
        fill_price = (
            price * (1 + adjustment)
            if request.side == "BUY"
            else price * (1 - adjustment)
        )

        result = OrderResult(
            order_id=uuid.uuid4(),
            status="FILLED",
            filled_quantity=request.quantity,
            avg_fill_price=fill_price,
            timestamp=datetime.now(timezone.utc),
        )
        logger.info("Zerodha stub: simulated fill for %s", request.symbol)
        return result

    def cancel_order(self, order_id: uuid.UUID) -> bool:
        """Stub: cancellation not implemented."""
        logger.warning("Zerodha stub: cancel not implemented")
        return False

    def get_positions(
        self, tenant_id: uuid.UUID, portfolio_id: uuid.UUID
    ) -> list[dict]:
        from app.models import Position  # avoid circular imports

        positions = (
            self.db.query(Position)
            .filter(
                Position.tenant_id == tenant_id,
                Position.portfolio_id == portfolio_id,
            )
            .all()
        )
        return [
            {
                "symbol": p.symbol,
                "exchange": p.exchange,
                "quantity": float(p.quantity),
                "avg_entry_price": float(p.avg_entry_price),
                "unrealized_pnl": float(p.unrealized_pnl)
                if p.unrealized_pnl is not None
                else None,
            }
            for p in positions
        ]

    def get_orders(self, tenant_id: uuid.UUID) -> list[dict]:
        """Stub: returns no orders."""
        return []

    def get_holdings(self, tenant_id: uuid.UUID) -> list[dict]:
        """Stub: returns no holdings."""
        return []

    def get_margin(self, tenant_id: uuid.UUID) -> dict:
        """Stub: returns zeroed margin."""
        return {"available": 0.0, "used": 0.0}
