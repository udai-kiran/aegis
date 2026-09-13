"""AI strategy allocator: ties regime + health + bandit into decisions."""

from __future__ import annotations

import logging
import uuid

from sqlalchemy.orm import Session

from app.intelligence.bandit import ThompsonSamplingBandit

logger = logging.getLogger(__name__)

# Default reward function lambda parameters (PRD §34)
DEFAULT_REWARD_PARAMS = {
    "lambda_drawdown": 0.3,
    "lambda_volatility": 0.2,
    "lambda_transaction_cost": 0.1,
    "lambda_tail_risk": 0.1,
}


def compute_allocation(
    db: Session,
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    mode: str = "LIVE",
) -> dict:
    """Compute AI strategy allocation for a tenant portfolio.

    Returns a dict with: strategy_weights, cash_weight, confidence,
    market_regime_id, context_snapshot, explanation, reward_params.
    """
    from app.intelligence.regime import compute_regime as _compute_regime
    from app.intelligence.health import evaluate_health
    from app.models import Portfolio, Strategy, StrategyConfig, MarketRegime, OHLCVBar

    # 1. Get portfolio and its active strategy configs
    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if portfolio is None:
        return _empty_allocation("Portfolio not found", mode=mode)

    configs = (
        db.query(StrategyConfig)
        .join(Strategy, StrategyConfig.strategy_id == Strategy.id)
        .filter(
            StrategyConfig.tenant_id == tenant_id,
            StrategyConfig.portfolio_id == portfolio_id,
            StrategyConfig.lifecycle_status.in_(
                [
                    "PAPER_TRADING",
                    "SHADOW_TRADING",
                    "LIVE_LOW_CAPITAL",
                    "LIVE_FULL",
                    "REDUCED_CAPITAL",
                ]
            ),
            Strategy.is_active.is_(True),
        )
        .all()
    )

    if not configs:
        return _empty_allocation("No strategy configs for portfolio", mode=mode)

    # 1b. Gather recent news sentiment context
    from app.models import NewsItem

    recent_news = (
        db.query(NewsItem)
        .filter(NewsItem.tenant_id == tenant_id)
        .order_by(NewsItem.published_at.desc())
        .limit(10)
        .all()
    )
    news_sentiment = None
    if recent_news:
        scores = [float(n.sentiment_score) for n in recent_news]
        news_sentiment = round(sum(scores) / len(scores), 4)

    # 2. Compute regime from most recent OHLCV data
    # Find most recent symbol in portfolio OHLCV data
    recent_bar = (
        db.query(OHLCVBar)
        .filter(OHLCVBar.tenant_id == tenant_id)
        .order_by(OHLCVBar.timestamp.desc())
        .first()
    )
    regime_result = None
    market_regime_id = None
    if recent_bar:
        regime_result = _compute_regime(
            db,
            symbol=recent_bar.symbol,
            exchange=recent_bar.exchange,
            timeframe=recent_bar.timeframe,
            tenant_id=tenant_id,
        )
        # Persist regime
        regime = MarketRegime(
            regime_label=regime_result["regime_label"],
            features=regime_result["features"],
            confidence=regime_result["confidence"],
            symbol=recent_bar.symbol,
            exchange=recent_bar.exchange,
            timeframe=recent_bar.timeframe,
        )
        db.add(regime)
        db.flush()
        market_regime_id = regime.id

    # 3. Evaluate health for each strategy config
    health_scores: dict[str, float] = {}
    health_details: dict[str, dict] = {}
    arm_names: list[str] = []

    for config in configs:
        health = evaluate_health(db, tenant_id, config.id, portfolio_id)
        # Use strategy_config id as arm name (will map back later)
        arm_key = str(config.id)
        health_scores[arm_key] = health["health_score"]
        health_details[arm_key] = health
        arm_names.append(arm_key)

    # Always include CASH as an arm
    arm_names.append("CASH")
    health_scores["CASH"] = 50.0  # Neutral health for cash

    # 4. Run bandit
    bandit = ThompsonSamplingBandit.load_or_create(
        db, tenant_id, portfolio_id, arm_names
    )
    regime_features = regime_result["features"] if regime_result else {}
    weights = bandit.select(
        regime_features=regime_features,
        health_scores=health_scores,
    )

    bandit.save_state(db, tenant_id, portfolio_id)

    # Extract cash weight
    cash_weight = weights.pop("CASH", 0.0)
    strategy_weights = weights

    # 5. Build context snapshot and explanation
    context_snapshot = {
        "market_regime": regime_result if regime_result else {},
        "health_scores": health_details,
        "news_sentiment": news_sentiment,
        "news_count": len(recent_news),
        "portfolio": {
            "current_equity": float(portfolio.current_equity),
            "cash": float(portfolio.cash),
            "trading_mode": portfolio.trading_mode,
        },
    }

    explanation_parts = []
    regime_label = regime_result["regime_label"] if regime_result else "UNKNOWN"
    explanation_parts.append(f"Market regime: {regime_label}.")
    if news_sentiment is not None:
        explanation_parts.append(
            f"News sentiment: {news_sentiment:+.2f} ({len(recent_news)} items)."
        )

    for config_id, weight in strategy_weights.items():
        health = health_details.get(config_id, {})
        status = health.get("health_status", "UNKNOWN")
        explanation_parts.append(
            f"Strategy {config_id[:8]}: weight={weight:.1%}, health={status}."
        )
    explanation_parts.append(f"Cash allocation: {cash_weight:.1%}.")
    if mode == "SHADOW":
        explanation_parts.append("Running in SHADOW mode (no live effect).")

    explanation = " ".join(explanation_parts)
    confidence = bandit.get_confidence()

    logger.info(
        "Allocation computed for tenant=%s portfolio=%s mode=%s: %d strategies + cash=%.1f%%",
        tenant_id,
        portfolio_id,
        mode,
        len(strategy_weights),
        cash_weight * 100,
    )

    return {
        "strategy_weights": strategy_weights,
        "cash_weight": round(cash_weight, 4),
        "confidence": confidence,
        "market_regime_id": market_regime_id,
        "context_snapshot": context_snapshot,
        "explanation": explanation,
        "reward_params": DEFAULT_REWARD_PARAMS,
        "mode": mode,
    }


def _empty_allocation(reason: str, mode: str = "LIVE") -> dict:
    """Return an empty allocation result with explanation."""
    return {
        "strategy_weights": {},
        "cash_weight": 1.0,
        "confidence": 0.0,
        "market_regime_id": None,
        "context_snapshot": {},
        "explanation": reason,
        "reward_params": DEFAULT_REWARD_PARAMS,
        "mode": mode,
    }
