"""Momentum strategy: go long/short when lookback returns exceed a threshold."""

from __future__ import annotations

import math

import pandas as pd

from app.strategies.base import Strategy, StrategyContext, StrategySignal


class MomentumStrategy(Strategy):
    """Emits signals when close-to-close returns over the lookback window
    exceed the configured threshold."""

    def __init__(self) -> None:
        self.parameters: dict = {"lookback": 20, "threshold": 0.02}

    @property
    def name(self) -> str:
        return "momentum"

    @property
    def strategy_type(self) -> str:
        return "momentum"

    def on_market_event(
        self,
        context: StrategyContext,
        prices: pd.DataFrame,
        portfolio_state: dict,
    ) -> list[StrategySignal]:
        if prices.empty:
            return []

        lookback: int = self.parameters["lookback"]
        threshold: float = self.parameters["threshold"]

        ret = prices["close"].pct_change(lookback).iloc[-1]
        if ret is None or math.isnan(ret):
            return []

        magnitude = min(abs(ret) / threshold, 1.0) if threshold > 0 else 0.0
        if ret > threshold:
            signal_value = 1.0 * magnitude
        elif ret < -threshold:
            signal_value = -1.0 * magnitude
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
                metadata={"return": ret, "lookback": lookback, "threshold": threshold},
            )
        ]
