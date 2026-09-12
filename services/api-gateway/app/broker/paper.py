"""Paper broker: simulated order execution for backtests and dry-runs."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.broker.base import Broker, OrderRequest, OrderResult

logger = logging.getLogger(__name__)


class PaperBroker(Broker):
    """Simulated broker that fills orders immediately at given prices.

    Args:
        db: SQLAlchemy session used for position lookups.
        slippage_bps: Slippage in basis points applied to market fills.
    """

    def __init__(self, db: Session, slippage_bps: float = 0.0) -> None:
        self.db = db
        self.slippage_bps = slippage_bps

    def place_order(self, request: OrderRequest) -> OrderResult:
        price = request.price

        if request.order_type == "LIMIT":
            if price is None:
                return self._reject(request, "Limit price not provided")
            fills = (request.side == "BUY" and price >= request.price) or (
                request.side == "SELL" and price <= request.price
            )
            if not fills:
                return self._reject(request, "Limit price not met")
        elif price is None:
            return self._reject(request, "Market price not provided")

        adjustment = self.slippage_bps / 10000
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
        logger.info(
            "Paper fill: %s %s %s qty=%s price=%.4f",
            request.side,
            request.symbol,
            request.exchange,
            request.quantity,
            fill_price,
        )
        return result

    @staticmethod
    def _reject(request: OrderRequest, reason: str) -> OrderResult:
        logger.warning(
            "Paper order rejected: %s %s — %s", request.side, request.symbol, reason
        )
        return OrderResult(
            order_id=uuid.uuid4(),
            status="REJECTED",
            filled_quantity=0.0,
            avg_fill_price=0.0,
            reject_reason=reason,
            timestamp=datetime.now(timezone.utc),
        )

    def cancel_order(self, order_id: uuid.UUID) -> bool:
        """Paper orders fill instantly, so there is never anything to cancel."""
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
