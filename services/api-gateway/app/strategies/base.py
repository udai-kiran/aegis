"""Base classes for trading strategies."""

from __future__ import annotations

import abc
import uuid
from dataclasses import dataclass
from datetime import datetime

import pandas as pd


@dataclass
class StrategySignal:
    """A single trading signal emitted by a strategy."""

    instrument: str
    timestamp: datetime
    signal: float  # range -1.0 to +1.0
    confidence: float
    expected_return: float | None = None
    expected_volatility: float | None = None
    horizon: str | None = None
    stop_price: float | None = None
    target_price: float | None = None
    metadata: dict | None = None


@dataclass
class StrategyContext:
    """Identifiers describing which tenant/portfolio/strategy instance is running."""

    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_instance_id: uuid.UUID


class Strategy(abc.ABC):
    """Abstract base class for trading strategies."""

    @property
    @abc.abstractmethod
    def name(self) -> str:
        """Human-readable strategy name."""

    @property
    @abc.abstractmethod
    def strategy_type(self) -> str:
        """Strategy type identifier (registry key)."""

    @abc.abstractmethod
    def on_market_event(
        self,
        context: StrategyContext,
        prices: pd.DataFrame,
        portfolio_state: dict,
    ) -> list[StrategySignal]:
        """Handle a market event.

        Args:
            context: Tenant/portfolio/strategy-instance identifiers.
            prices: OHLCV DataFrame with columns: timestamp, open, high, low,
                close, volume.
            portfolio_state: Current portfolio state (positions, cash, etc.).
        """

    def configure(self, parameters: dict) -> None:
        """Apply configuration parameters, merging with existing defaults."""
        self.parameters = {**self.parameters, **parameters}
