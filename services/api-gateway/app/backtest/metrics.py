"""Backtest performance metrics (PRD §23)."""

from __future__ import annotations

import math

import numpy as np
import pandas as pd

ANNUALIZATION_FACTOR = 252  # trading days per year


def calculate_metrics(equity_curve: pd.Series, trades: list[dict]) -> dict:
    """Calculate standard backtest performance metrics.

    Args:
        equity_curve: Series indexed by date/datetime whose values are
            portfolio equity.
        trades: List of dicts with keys ``pnl`` (float), ``entry_date`` and
            ``exit_date``.

    Returns:
        Flat dict of ``metric_name -> float`` for the PRD §23 metrics.
    """
    equity = pd.Series(equity_curve, dtype="float64")
    n_points = len(equity)

    returns = (
        equity.pct_change().dropna() if n_points >= 2 else pd.Series(dtype="float64")
    )

    # --- Equity-curve metrics -------------------------------------------------
    initial = float(equity.iloc[0]) if n_points >= 1 else 0.0
    final = float(equity.iloc[-1]) if n_points >= 1 else 0.0

    gross_return = (final - initial) / initial if initial else 0.0
    net_return = gross_return  # fees not modelled yet

    periods = n_points - 1
    if periods > 0 and initial > 0 and final >= 0:
        cagr = (final / initial) ** (ANNUALIZATION_FACTOR / periods) - 1.0
    else:
        cagr = 0.0

    mean_return = float(returns.mean()) if not returns.empty else 0.0
    std_return = float(returns.std()) if len(returns) >= 2 else 0.0
    sharpe = (
        mean_return / std_return * math.sqrt(ANNUALIZATION_FACTOR)
        if std_return
        else 0.0
    )

    if not returns.empty:
        downside = np.minimum(returns.to_numpy(), 0.0)
        downside_dev = float(np.sqrt(np.mean(np.square(downside))))
    else:
        downside_dev = 0.0
    sortino = (
        mean_return / downside_dev * math.sqrt(ANNUALIZATION_FACTOR)
        if downside_dev
        else 0.0
    )

    if n_points >= 1:
        running_max = equity.cummax()
        drawdown = (equity - running_max) / running_max.replace(0.0, np.nan)
        max_drawdown = -float(drawdown.min()) if drawdown.notna().any() else 0.0
    else:
        max_drawdown = 0.0
    max_drawdown = abs(max_drawdown)

    calmar = cagr / max_drawdown if max_drawdown else 0.0

    worst_day = float(returns.min()) if not returns.empty else 0.0
    best_day = float(returns.max()) if not returns.empty else 0.0

    # --- Trade metrics --------------------------------------------------------
    pnls = [float(t.get("pnl", 0.0)) for t in trades]
    wins = [pnl for pnl in pnls if pnl > 0]
    losses = [pnl for pnl in pnls if pnl < 0]
    total_trades = len(pnls)

    gross_loss = abs(sum(losses))
    profit_factor = sum(wins) / gross_loss if gross_loss else 0.0
    win_rate = len(wins) / total_trades if total_trades else 0.0
    avg_winner = sum(wins) / len(wins) if wins else 0.0
    avg_loser = sum(losses) / len(losses) if losses else 0.0
    expected_value = sum(pnls) / total_trades if total_trades else 0.0

    max_losing_streak = 0
    current_streak = 0
    for pnl in pnls:
        if pnl < 0:
            current_streak += 1
            max_losing_streak = max(max_losing_streak, current_streak)
        else:
            current_streak = 0

    metrics = {
        "gross_return": gross_return,
        "net_return": net_return,
        "cagr": cagr,
        "sharpe": sharpe,
        "sortino": sortino,
        "calmar": calmar,
        "max_drawdown": max_drawdown,
        "profit_factor": profit_factor,
        "win_rate": win_rate,
        "avg_winner": avg_winner,
        "avg_loser": avg_loser,
        "expected_value": expected_value,
        "total_trades": total_trades,
        "worst_day": worst_day,
        "best_day": best_day,
        "max_losing_streak": max_losing_streak,
    }
    return {name: round(float(value), 6) for name, value in metrics.items()}
