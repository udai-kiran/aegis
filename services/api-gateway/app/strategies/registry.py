"""Registry mapping strategy type identifiers to strategy classes."""

from __future__ import annotations

from app.strategies.mean_reversion import MeanReversionStrategy
from app.strategies.momentum import MomentumStrategy

STRATEGY_REGISTRY: dict[str, type] = {
    "momentum": MomentumStrategy,
    "mean_reversion": MeanReversionStrategy,
}
