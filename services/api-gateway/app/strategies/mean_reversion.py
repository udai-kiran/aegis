"""Mean reversion strategy: fade moves beyond N standard deviations of the mean."""

from __future__ import annotations

import math

import pandas as pd

from app.strategies.base import Strategy, StrategyContext, StrategySignal


class MeanReversionStrategy(Strategy):
    """Emits contrarian signals when close deviates from its rolling mean by
    more than num_std standard deviations over the lookback window."""

    def __init__(self) -> None:
        self.parameters: dict = {"lookback": 20, "num_std": 2.0}

    @property
    def name(self) -> str:
        return "mean_reversion"

    @property
    def strategy_type(self) -> str:
        return "mean_reversion"

    def on_market_event(
        self,
        context: StrategyContext,
        prices: pd.DataFrame,
        portfolio_state: dict,
    ) -> list[StrategySignal]:
        if prices.empty:
            return []

        lookback: int = self.parameters["lookback"]
        num_std: float = self.parameters["num_std"]

        close = prices["close"]
        mean = close.rolling(lookback).mean().iloc[-1]
        std = close.rolling(lookback).std().iloc[-1]
        if (
            mean is None
            or std is None
            or math.isnan(mean)
            or math.isnan(std)
            or std == 0
        ):
            return []

        z = (close.iloc[-1] - mean) / std
        magnitude = min(abs(z) / num_std, 1.0)

        if z > num_std:
            # Price well above mean: expect downward reversion.
            signal_value = -1.0 * magnitude
        elif z < -num_std:
            # Price well below mean: expect upward reversion.
            signal_value = 1.0 * magnitude
        else:
            return []

        instrument = prices.index.name or "UNKNOWN"
        timestamp = prices["timestamp"].iloc[-1]

        return [
            StrategySignal(
                instrument=instrument,
                timestamp=timestamp,
                signal=signal_value,
                confidence=magnitude,
                metadata={"z_score": z, "lookback": lookback, "num_std": num_std},
            )
        ]
