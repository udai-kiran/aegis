"""Strategy health scoring from backtest and trading performance."""

from __future__ import annotations

import logging
import uuid

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def evaluate_health(
    db: Session,
    tenant_id: uuid.UUID,
    strategy_config_id: uuid.UUID,
    portfolio_id: uuid.UUID,
) -> dict:
    """Evaluate strategy health from backtest metrics.

    Returns a dict with: win_rate, avg_return, sharpe_ratio, max_drawdown,
    total_trades, recent_pnl, health_score, health_status.
    """
    from app.models import BacktestRun, StrategyConfig  # lazy imports

    # Verify strategy config exists and belongs to tenant
    config = (
        db.query(StrategyConfig)
        .filter(
            StrategyConfig.id == strategy_config_id,
            StrategyConfig.tenant_id == tenant_id,
            StrategyConfig.portfolio_id == portfolio_id,
        )
        .first()
    )
    if config is None:
        return {
            "win_rate": 0.0,
            "avg_return": 0.0,
            "sharpe_ratio": None,
            "max_drawdown": None,
            "total_trades": 0,
            "recent_pnl": 0.0,
            "health_score": 0.0,
            "health_status": "UNKNOWN",
        }

    # Get completed backtests for this strategy config
    backtests = (
        db.query(BacktestRun)
        .filter(
            BacktestRun.tenant_id == tenant_id,
            BacktestRun.strategy_config_id == strategy_config_id,
            BacktestRun.portfolio_id == portfolio_id,
            BacktestRun.status == "COMPLETED",
        )
        .order_by(BacktestRun.created_at.desc())
        .limit(20)
        .all()
    )

    if not backtests:
        return {
            "win_rate": 0.0,
            "avg_return": 0.0,
            "sharpe_ratio": None,
            "max_drawdown": None,
            "total_trades": 0,
            "recent_pnl": 0.0,
            "health_score": 0.0,
            "health_status": "NO_DATA",
        }

    # Aggregate metrics from backtest results
    total_return = 0.0
    total_trades = 0
    win_rate_values = []
    sharpe_values = []
    drawdown_values = []

    for bt in backtests:
        metrics = bt.metrics or {}
        ret = metrics.get("net_return", 0.0)
        total_return += ret
        trades = metrics.get("total_trades", 0)
        total_trades += trades
        wr = metrics.get("win_rate")
        if wr is not None:
            win_rate_values.append(wr)
        sharpe = metrics.get("sharpe")
        if sharpe is not None:
            sharpe_values.append(sharpe)
        dd = metrics.get("max_drawdown")
        if dd is not None:
            drawdown_values.append(dd)

    n = len(backtests)
    win_rate = sum(win_rate_values) / len(win_rate_values) if win_rate_values else 0.0
    avg_return = total_return / n if n > 0 else 0.0
    sharpe_ratio = sum(sharpe_values) / len(sharpe_values) if sharpe_values else None
    max_drawdown = max(drawdown_values) if drawdown_values else None

    # Most recent backtest PnL as recent_pnl
    recent_metrics = backtests[0].metrics or {}
    recent_pnl = recent_metrics.get("net_return", 0.0)

    # Compute composite health score (0-100)
    score = _compute_health_score(win_rate, avg_return, sharpe_ratio, max_drawdown)
    status = _health_status(score)

    logger.info(
        "Health evaluated for config %s: score=%.1f status=%s",
        strategy_config_id,
        score,
        status,
    )
    return {
        "win_rate": round(win_rate, 4),
        "avg_return": round(avg_return, 4),
        "sharpe_ratio": round(sharpe_ratio, 4) if sharpe_ratio is not None else None,
        "max_drawdown": round(max_drawdown, 4) if max_drawdown is not None else None,
        "total_trades": total_trades,
        "recent_pnl": round(recent_pnl, 4),
        "health_score": round(score, 4),
        "health_status": status,
    }


def _compute_health_score(
    win_rate: float,
    avg_return: float,
    sharpe: float | None,
    max_drawdown: float | None,
) -> float:
    """Composite health score from 0 to 100."""
    score = 0.0

    # Win rate contribution (0-30)
    score += min(win_rate * 30, 30.0)

    # Return contribution (0-30): positive returns boost score
    if avg_return > 0:
        score += min(avg_return * 100, 30.0)

    # Sharpe contribution (0-25)
    if sharpe is not None and sharpe > 0:
        score += min(sharpe * 10, 25.0)

    # Drawdown penalty (0 to -15): high drawdown reduces score
    if max_drawdown is not None and max_drawdown > 0:
        score -= min(max_drawdown * 50, 15.0)

    return max(0.0, min(100.0, score))


def _health_status(score: float) -> str:
    """Classify health status from score."""
    if score >= 60:
        return "HEALTHY"
    elif score >= 30:
        return "DEGRADED"
    else:
        return "FAILING"
