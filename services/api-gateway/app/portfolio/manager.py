"""Portfolio manager: converts strategy signals into target exposures and trade intents."""
from __future__ import annotations

import logging
import math
import uuid
from dataclasses import dataclass

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


@dataclass
class TradeProposal:
    """A proposed trade derived from a strategy signal and current portfolio state."""

    symbol: str
    exchange: str
    side: str  # "BUY" or "SELL"
    quantity: float
    target_value: float
    signal_id: uuid.UUID | None = None


class PortfolioManager:
    """Converts strategy signals into trade proposals and persists trade intents."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def process_signal(
        self,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        signal_id: uuid.UUID,
        symbol: str,
        exchange: str,
        signal_value: float,
        confidence: float,
        current_price: float,
    ) -> TradeProposal | None:
        """Convert a single strategy signal into a TradeProposal, or None if no trade is needed."""
        from app.models import Portfolio, Position

        portfolio = self.db.get(Portfolio, portfolio_id)
        if portfolio is None:
            logger.warning("Portfolio %s not found; ignoring signal %s", portfolio_id, signal_id)
            return None

        current_equity = float(portfolio.current_equity or 0)
        if current_equity <= 0:
            logger.warning(
                "Portfolio %s has non-positive equity (%s); ignoring signal %s",
                portfolio_id,
                current_equity,
                signal_id,
            )
            return None

        # Target allocation in range -1.0 to +1.0 after multiplication.
        allocation = signal_value * confidence

        position = (
            self.db.query(Position)
            .filter(
                Position.tenant_id == tenant_id,
                Position.portfolio_id == portfolio_id,
                Position.symbol == symbol,
                Position.exchange == exchange,
            )
            .one_or_none()
        )
        current_quantity = float(position.quantity) if position is not None else 0.0

        if abs(allocation) < 0.01:
            return None

        target_value = current_equity * abs(allocation)
        target_quantity = math.floor(target_value / current_price) if current_price > 0 else 0

        if allocation > 0:
            # Wants long: buy the difference between target and current holding.
            side = "BUY"
            net_qty = target_quantity - current_quantity
        else:
            # Wants short: no short selling in MVP, so only sell what we hold.
            side = "SELL"
            net_qty = min(abs(target_quantity), current_quantity)

        if net_qty <= 0:
            return None

        return TradeProposal(
            symbol=symbol,
            exchange=exchange,
            side=side,
            quantity=net_qty,
            target_value=target_value,
            signal_id=signal_id,
        )

    def generate_trade_intents(
        self,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        proposals: list[TradeProposal],
    ) -> list[uuid.UUID]:
        """Persist TradeProposal objects as PENDING TradeIntent rows; returns their IDs."""
        from app.models import TradeIntent

        intent_ids: list[uuid.UUID] = []
        for proposal in proposals:
            intent = TradeIntent(
                tenant_id=tenant_id,
                portfolio_id=portfolio_id,
                signal_id=proposal.signal_id,
                symbol=proposal.symbol,
                exchange=proposal.exchange,
                side=proposal.side,
                target_quantity=proposal.quantity,
                target_value=proposal.target_value,
                status="PENDING",
            )
            self.db.add(intent)
            intent_ids.append(intent.id)
        self.db.flush()
        logger.info("Created %d trade intents for portfolio %s", len(intent_ids), portfolio_id)
        return intent_ids
