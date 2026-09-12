"""Strategy abstraction layer: base classes and built-in strategy registry."""

from __future__ import annotations

from app.strategies.base import Strategy, StrategyContext, StrategySignal
from app.strategies.registry import STRATEGY_REGISTRY

__all__ = ["Strategy", "StrategyContext", "StrategySignal", "STRATEGY_REGISTRY"]
