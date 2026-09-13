"""Counterfactual evaluation: compare chosen vs alternative strategies (PRD §27)."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def evaluate_counterfactual(
    db: Session,
    tenant_id: uuid.UUID,
    ai_decision_id: uuid.UUID,
    evaluation_start: datetime,
    evaluation_end: datetime,
) -> dict:
    """Evaluate what each strategy would have returned vs what was chosen.

    Uses backtest metrics and shadow results within the evaluation window
    to estimate hypothetical returns. Returns a dict with:
    actual_weighted_return, best_alternative_return, regret, comparisons.
    """
    from app.models import (
        AIDecision,
        ShadowResult,
        StrategyConfig,
        Strategy,
        BacktestRun,
    )

    decision = (
        db.query(AIDecision)
        .filter(
            AIDecision.id == ai_decision_id,
            AIDecision.tenant_id == tenant_id,
        )
        .first()
    )
    if decision is None:
        return _empty_result(ai_decision_id, evaluation_start, evaluation_end)

    strategy_weights = decision.strategy_weights or {}
    portfolio_id = decision.portfolio_id

    # Get all strategy configs for this portfolio
    configs = (
        db.query(StrategyConfig)
        .join(Strategy, StrategyConfig.strategy_id == Strategy.id)
        .filter(
            StrategyConfig.tenant_id == tenant_id,
            StrategyConfig.portfolio_id == portfolio_id,
        )
        .all()
    )

    comparisons = []
    actual_weighted = 0.0
    for config in configs:
        config_id_str = str(config.id)
        was_chosen = config_id_str in strategy_weights
        weight = strategy_weights.get(config_id_str, 0.0)

        # Try shadow results first
        shadow = (
            db.query(ShadowResult)
            .filter(
                ShadowResult.tenant_id == tenant_id,
                ShadowResult.ai_decision_id == ai_decision_id,
                ShadowResult.strategy_config_id == config.id,
                ShadowResult.created_at >= evaluation_start,
                ShadowResult.created_at <= evaluation_end,
            )
            .first()
        )

        if shadow is not None:
            hyp_return = float(shadow.hypothetical_return)
            actual_return = float(shadow.actual_return)
        else:
            # Fall back to most recent backtest metric
            bt = (
                db.query(BacktestRun)
                .filter(
                    BacktestRun.tenant_id == tenant_id,
                    BacktestRun.strategy_config_id == config.id,
                    BacktestRun.portfolio_id == portfolio_id,
                    BacktestRun.status == "COMPLETED",
                    BacktestRun.created_at >= evaluation_start,
                    BacktestRun.created_at <= evaluation_end,
                )
                .order_by(BacktestRun.created_at.desc())
                .first()
            )
            if bt and bt.metrics:
                hyp_return = bt.metrics.get("net_return", 0.0)
            else:
                hyp_return = 0.0
            actual_return = hyp_return

        if was_chosen:
            actual_weighted += weight * actual_return

        # Get strategy name
        strategy = db.query(Strategy).filter(Strategy.id == config.strategy_id).first()
        strategy_name = strategy.name if strategy else "Unknown"

        comparisons.append(
            {
                "strategy_config_id": str(config.id),
                "strategy_name": strategy_name,
                "was_chosen": was_chosen,
                "weight": weight,
                "hypothetical_return": round(hyp_return, 4),
            }
        )

    # Best alternative: the single strategy with the highest hypothetical return
    # that was NOT chosen (or had zero weight)
    alternatives = [c for c in comparisons if not c["was_chosen"] or c["weight"] == 0]
    best_alt = max(
        (c["hypothetical_return"] for c in alternatives),
        default=0.0,
    )

    regret = round(max(0.0, best_alt - actual_weighted), 4)

    logger.info(
        "Counterfactual for decision %s: actual=%.4f best_alt=%.4f regret=%.4f",
        ai_decision_id,
        actual_weighted,
        best_alt,
        regret,
    )
    return {
        "ai_decision_id": str(ai_decision_id),
        "actual_weighted_return": round(actual_weighted, 4),
        "best_alternative_return": round(best_alt, 4),
        "regret": regret,
        "comparisons": comparisons,
        "evaluation_start": evaluation_start,
        "evaluation_end": evaluation_end,
    }


def _empty_result(
    ai_decision_id: uuid.UUID,
    evaluation_start: datetime,
    evaluation_end: datetime,
) -> dict:
    return {
        "ai_decision_id": str(ai_decision_id),
        "actual_weighted_return": 0.0,
        "best_alternative_return": 0.0,
        "regret": 0.0,
        "comparisons": [],
        "evaluation_start": evaluation_start,
        "evaluation_end": evaluation_end,
    }
