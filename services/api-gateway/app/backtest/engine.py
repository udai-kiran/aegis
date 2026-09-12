"""Backtest engine: simulates a strategy over historical OHLCV bars."""
from __future__ import annotations

import logging
import math
from datetime import datetime

import pandas as pd
from sqlalchemy.orm import Session

from app.backtest.metrics import calculate_metrics
from app.models import (
    BacktestRun,
    OHLCVBar,
    Portfolio,
    Strategy as StrategyModel,
    StrategyConfig,
)
from app.strategies.base import StrategyContext, StrategySignal
from app.strategies.registry import STRATEGY_REGISTRY

logger = logging.getLogger(__name__)


def run_backtest(db: Session, backtest_run: BacktestRun) -> dict:
    """Execute a backtest and return computed metrics.

    Raises ValueError when the strategy type is unknown or no market data
    exists for the requested date range.
    """
    # 1-2. Load config and strategy model
    config = db.get(StrategyConfig, backtest_run.strategy_config_id)
    if config is None:
        raise ValueError(f"StrategyConfig {backtest_run.strategy_config_id} not found")

    strategy_model = db.get(StrategyModel, config.strategy_id)
    if strategy_model is None:
        raise ValueError(f"Strategy {config.strategy_id} not found")

    # 3-4. Look up and instantiate the strategy
    strategy_cls = STRATEGY_REGISTRY.get(strategy_model.strategy_type)
    if strategy_cls is None:
        raise ValueError(f"Unknown strategy type: {strategy_model.strategy_type}")

    parameters: dict = {**(config.parameters or {}), **(backtest_run.parameters or {})}
    strategy = strategy_cls()
    strategy.configure(parameters)

    # 5. Load OHLCV bars for the tenant within the backtest date range
    bars = (
        db.query(OHLCVBar)
        .filter(
            OHLCVBar.tenant_id == backtest_run.tenant_id,
            OHLCVBar.symbol == backtest_run.symbol,
            OHLCVBar.exchange == backtest_run.exchange,
            OHLCVBar.timeframe == backtest_run.timeframe,
            OHLCVBar.timestamp >= backtest_run.start_date,
            OHLCVBar.timestamp <= backtest_run.end_date,
        )
        .order_by(OHLCVBar.timestamp.asc())
        .all()
    )
    if not bars:
        raise ValueError("No market data found for the given date range")

    # 6. Convert bars to a DataFrame
    prices = pd.DataFrame(
        {
            "timestamp": [bar.timestamp for bar in bars],
            "open": [float(bar.open) for bar in bars],
            "high": [float(bar.high) for bar in bars],
            "low": [float(bar.low) for bar in bars],
            "close": [float(bar.close) for bar in bars],
            "volume": [float(bar.volume) for bar in bars],
        }
    )

    # 7. Build strategy context
    context = StrategyContext(
        tenant_id=backtest_run.tenant_id,
        portfolio_id=backtest_run.portfolio_id,
        strategy_instance_id=config.id,
    )

    # 9. Equity simulation setup
    portfolio = db.get(Portfolio, backtest_run.portfolio_id)
    initial_capital = float(portfolio.starting_capital) if portfolio is not None else 0.0
    lookback = int(parameters.get("lookback", 20))

    cash = initial_capital
    position = 0.0
    open_trade: dict | None = None  # entry_price, entry_date
    trades: list[dict] = []
    equity: dict[datetime, float] = {}

    # 8. Simulate: feed a growing window of bars to the strategy
    n_bars = len(prices)
    for i in range(lookback, n_bars):
        window = prices.iloc[: i + 1]
        portfolio_state = {"cash": cash, "position": position}
        signals: list[StrategySignal] = strategy.on_market_event(context, window, portfolio_state)

        timestamp: datetime = prices["timestamp"].iloc[i]
        close_price = float(prices["close"].iloc[i])

        # 9. Apply signals to the simple equity simulation
        for sig in signals:
            value = float(sig.signal)
            if value > 0 and close_price > 0:
                shares = math.floor(cash * abs(value) / close_price)
                if shares > 0:
                    cash -= shares * close_price
                    position += shares
                    if open_trade is None:
                        open_trade = {"entry_price": close_price, "entry_date": timestamp}
            elif value < 0 and position > 0:
                shares = min(position, abs(position * value))
                if position - shares < 1e-9:
                    shares = position
                if shares > 0:
                    cash += shares * close_price
                    position -= shares
                    if open_trade is not None:
                        trades.append(
                            {
                                "pnl": (close_price - open_trade["entry_price"]) * shares,
                                "entry_date": open_trade["entry_date"],
                                "exit_date": timestamp,
                            }
                        )
                        if position <= 1e-9:
                            position = 0.0
                            open_trade = None

        equity[timestamp] = cash + position * close_price

    # Close any still-open trade at the final close price
    if open_trade is not None and position > 0 and n_bars > lookback:
        last_ts: datetime = prices["timestamp"].iloc[-1]
        last_close = float(prices["close"].iloc[-1])
        trades.append(
            {
                "pnl": (last_close - open_trade["entry_price"]) * position,
                "entry_date": open_trade["entry_date"],
                "exit_date": last_ts,
            }
        )
        open_trade = None

    # 10. Compute metrics
    equity_curve = pd.Series(equity, dtype="float64")
    metrics = calculate_metrics(equity_curve, trades)

    logger.info(
        "Backtest %s completed: %d bars, %d trades",
        backtest_run.id,
        n_bars,
        len(trades),
    )
    return metrics
