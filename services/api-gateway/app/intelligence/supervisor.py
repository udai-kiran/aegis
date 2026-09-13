"""LLM Supervisor: rule-based advisory recommendations (PRD §35).

This module provides supervisory recommendations for portfolio management.
The default implementation uses deterministic rules; a future LLM backend
can replace the rule engine while keeping the same interface.

SAFETY: This module must NEVER import or call any order-placement function.
It produces recommendations only — execution is handled by separate modules.
"""

from __future__ import annotations

import logging
import uuid

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def generate_recommendations(
    db: Session,
    tenant_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    decision_id: uuid.UUID | None = None,
) -> list[dict]:
    """Generate supervisor recommendations for a portfolio.

    Analyzes current strategy health, market regime, and portfolio state
    to produce advisory actions. Returns a list of recommendation dicts,
    each with: action_type, recommendation, reasoning, confidence.
    """
    from app.models import (
        Portfolio,
        StrategyConfig,
        StrategyHealthScore,
        Strategy,
    )

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if portfolio is None:
        return []

    # Get latest health scores for all strategies in this portfolio
    configs = (
        db.query(StrategyConfig)
        .join(Strategy, StrategyConfig.strategy_id == Strategy.id)
        .filter(
            StrategyConfig.tenant_id == tenant_id,
            StrategyConfig.portfolio_id == portfolio_id,
            Strategy.is_active.is_(True),
        )
        .all()
    )

    if not configs:
        return []

    recommendations: list[dict] = []

    for config in configs:
        # Get most recent health score
        health = (
            db.query(StrategyHealthScore)
            .filter(
                StrategyHealthScore.tenant_id == tenant_id,
                StrategyHealthScore.strategy_config_id == config.id,
                StrategyHealthScore.portfolio_id == portfolio_id,
            )
            .order_by(StrategyHealthScore.evaluated_at.desc())
            .first()
        )
        if health is None:
            continue

        # Rule 1: Recommend disabling critically failing strategies
        if health.health_status == "FAILING" and float(health.health_score) < 15:
            recommendations.append(
                {
                    "action_type": "DISABLE_STRATEGY",
                    "recommendation": {
                        "strategy_config_id": str(config.id),
                        "suggested_status": "DISABLED",
                    },
                    "reasoning": (
                        f"Strategy {config.id} has health score {float(health.health_score):.1f} "
                        f"(FAILING). Recommend disabling to prevent further losses."
                    ),
                    "confidence": 0.85,
                }
            )

        # Rule 2: Recommend weight reduction for degraded strategies
        elif health.health_status == "DEGRADED":
            recommendations.append(
                {
                    "action_type": "WEIGHT_CHANGE",
                    "recommendation": {
                        "strategy_config_id": str(config.id),
                        "suggested_weight_multiplier": 0.5,
                    },
                    "reasoning": (
                        f"Strategy {config.id} is DEGRADED (score={float(health.health_score):.1f}). "
                        f"Recommend reducing allocation weight by 50%."
                    ),
                    "confidence": 0.7,
                }
            )

        # Rule 3: Recommend position reduction if max drawdown is high
        if health.max_drawdown is not None and float(health.max_drawdown) > 10.0:
            recommendations.append(
                {
                    "action_type": "POSITION_REDUCTION",
                    "recommendation": {
                        "strategy_config_id": str(config.id),
                        "suggested_reduction_pct": 0.3,
                    },
                    "reasoning": (
                        f"Strategy {config.id} has max drawdown {float(health.max_drawdown):.1f}%. "
                        f"Recommend reducing position sizes by 30%."
                    ),
                    "confidence": 0.65,
                }
            )

    # Rule 4: Cash allocation recommendation based on overall portfolio health
    healthy_count = sum(
        1
        for c in configs
        if (
            h := db.query(StrategyHealthScore)
            .filter(
                StrategyHealthScore.tenant_id == tenant_id,
                StrategyHealthScore.strategy_config_id == c.id,
                StrategyHealthScore.portfolio_id == portfolio_id,
            )
            .order_by(StrategyHealthScore.evaluated_at.desc())
            .first()
        )
        is not None
        and h.health_status == "HEALTHY"
    )
    total = len(configs)
    if total > 0 and healthy_count / total < 0.5:
        recommendations.append(
            {
                "action_type": "CASH_ALLOCATION",
                "recommendation": {
                    "suggested_cash_weight": 0.4,
                },
                "reasoning": (
                    f"Only {healthy_count}/{total} strategies are HEALTHY. "
                    f"Recommend increasing cash allocation to 40% for risk reduction."
                ),
                "confidence": 0.75,
            }
        )

    logger.info(
        "Supervisor generated %d recommendations for tenant=%s portfolio=%s",
        len(recommendations),
        tenant_id,
        portfolio_id,
    )
    return recommendations
