"""Abstract broker interface and order datatypes."""

from __future__ import annotations

import abc
import uuid
from dataclasses import dataclass
from datetime import datetime


@dataclass
class OrderRequest:
    """An order placement request."""

    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    symbol: str
    side: str  # "BUY" or "SELL"
    quantity: float
    exchange: str = "NSE"
    order_type: str = "MARKET"
    price: float | None = None  # limit price, only for LIMIT orders


@dataclass
class OrderResult:
    """Result of an order placement attempt."""

    order_id: uuid.UUID
    status: str  # "FILLED", "REJECTED", "PARTIALLY_FILLED"
    filled_quantity: float
    avg_fill_price: float
    timestamp: datetime
    reject_reason: str | None = None


class Broker(abc.ABC):
    """Abstract broker interface."""

    @abc.abstractmethod
    def place_order(self, request: OrderRequest) -> OrderResult:
        """Place an order and return the execution result."""

    @abc.abstractmethod
    def cancel_order(self, order_id: uuid.UUID) -> bool:
        """Cancel an open order. Returns True if cancellation succeeded."""

    @abc.abstractmethod
    def get_positions(
        self, tenant_id: uuid.UUID, portfolio_id: uuid.UUID
    ) -> list[dict]:
        """Return open positions for a portfolio as a list of dicts."""
