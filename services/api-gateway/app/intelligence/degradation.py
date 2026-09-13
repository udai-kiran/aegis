"""Strategy degradation detection from rolling health scores."""

from __future__ import annotations

import logging
import uuid

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Thresholds for degradation detection
SCORE_DECLINE_WINDOW = 5  # consecutive evaluations to check
SHARPE_THRESHOLD = 0.5  # below this triggers alert
DRAWDOWN_SPIKE_PCT = 15.0  # above this triggers alert

# Lifecycle statuses from which auto-demotion is allowed. Demoting from any
# other status (DISABLED, QUARANTINED, DEVELOPMENT, SHADOW_ONLY, ...) would
# effectively promote the strategy back into active allocation, so it is
# skipped.
ACTIVE_LIFECYCLE_STATUSES = frozenset(
    {
        "PAPER_TRADING",
        "SHADOW_TRADING",
        "LIVE_LOW_CAPITAL",
        "LIVE_FULL",
        "REDUCED_CAPITAL",
    }
)


def check_degradation(
    db: Session,
    tenant_id: uuid.UUID,
    strategy_config_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    auto_demote: bool = False,
) -> dict:
    """Check if a strategy is degrading based on health score history.

    Returns a dict with: is_degrading, alerts (list), health_trend (list of recent scores).
    If auto_demote=True and degradation is detected, updates lifecycle_status.
    """
    from app.models import StrategyConfig, StrategyHealthScore, DegradationAlert

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
        return {"is_degrading": False, "alerts": [], "health_trend": []}

    # Get recent health scores, ordered newest first
    scores = (
        db.query(StrategyHealthScore)
        .filter(
            StrategyHealthScore.tenant_id == tenant_id,
            StrategyHealthScore.strategy_config_id == strategy_config_id,
            StrategyHealthScore.portfolio_id == portfolio_id,
        )
        .order_by(StrategyHealthScore.evaluated_at.desc())
        .limit(SCORE_DECLINE_WINDOW * 2)
        .all()
    )

    if not scores:
        return {"is_degrading": False, "alerts": [], "health_trend": []}

    # Health trend: chronological order (oldest first)
    health_trend = [float(s.health_score) for s in reversed(scores)]

    alerts: list[dict] = []

    # Check 1: Consecutive score decline
    if len(scores) >= SCORE_DECLINE_WINDOW:
        recent = [float(s.health_score) for s in scores[:SCORE_DECLINE_WINDOW]]
        # Check if each score is lower than the previous (monotonic decline)
        declining = all(recent[i] <= recent[i + 1] for i in range(len(recent) - 1))
        if declining and recent[0] < recent[-1]:
            decline_amount = recent[-1] - recent[0]
            severity = _severity_from_decline(decline_amount)
            alert = DegradationAlert(
                tenant_id=tenant_id,
                strategy_config_id=strategy_config_id,
                portfolio_id=portfolio_id,
                alert_type="SCORE_DECLINE",
                severity=severity,
                details={
                    "window": SCORE_DECLINE_WINDOW,
                    "start_score": recent[-1],
                    "end_score": recent[0],
                    "decline": decline_amount,
                },
            )
            db.add(alert)
            db.flush()
            alerts.append(_alert_to_dict(alert))

    # Check 2: Sharpe ratio below threshold
    latest = scores[0]
    if (
        latest.sharpe_ratio is not None
        and float(latest.sharpe_ratio) < SHARPE_THRESHOLD
    ):
        alert = DegradationAlert(
            tenant_id=tenant_id,
            strategy_config_id=strategy_config_id,
            portfolio_id=portfolio_id,
            alert_type="SHARPE_BELOW_THRESHOLD",
            severity="MEDIUM" if float(latest.sharpe_ratio) > 0 else "HIGH",
            details={
                "sharpe_ratio": float(latest.sharpe_ratio),
                "threshold": SHARPE_THRESHOLD,
            },
        )
        db.add(alert)
        db.flush()
        alerts.append(_alert_to_dict(alert))

    # Check 3: Drawdown spike
    if (
        latest.max_drawdown is not None
        and float(latest.max_drawdown) > DRAWDOWN_SPIKE_PCT
    ):
        alert = DegradationAlert(
            tenant_id=tenant_id,
            strategy_config_id=strategy_config_id,
            portfolio_id=portfolio_id,
            alert_type="DRAWDOWN_SPIKE",
            severity="HIGH" if float(latest.max_drawdown) > 25.0 else "MEDIUM",
            details={
                "max_drawdown": float(latest.max_drawdown),
                "threshold": DRAWDOWN_SPIKE_PCT,
            },
        )
        db.add(alert)
        db.flush()
        alerts.append(_alert_to_dict(alert))

    is_degrading = len(alerts) > 0

    # Auto-demote if requested and degradation detected
    auto_action = None
    if auto_demote and is_degrading:
        worst_severity = _worst_severity(alerts)
        if worst_severity == "CRITICAL":
            auto_action = "DISABLED"
        elif worst_severity in ("HIGH", "MEDIUM"):
            auto_action = "REDUCED_CAPITAL"

        # Only demote strategies currently in an active state; never
        # "promote" a DISABLED/QUARANTINED/DEVELOPMENT/SHADOW_ONLY config
        # back into an allocatable state.
        if auto_action and config.lifecycle_status not in ACTIVE_LIFECYCLE_STATUSES:
            auto_action = None

        # Update the auto_action_taken on the most recent alert
        if alerts and auto_action:
            config.lifecycle_status = auto_action
            last_alert_id = uuid.UUID(alerts[-1]["id"])
            db_alert = (
                db.query(DegradationAlert)
                .filter(DegradationAlert.id == last_alert_id)
                .first()
            )
            if db_alert:
                db_alert.auto_action_taken = auto_action
            # Keep the response dict in sync with the DB object
            alerts[-1]["auto_action_taken"] = auto_action

            db.flush()
            logger.info(
                "Auto-demoted strategy config %s to %s",
                strategy_config_id,
                auto_action,
            )

    logger.info(
        "Degradation check for config %s: is_degrading=%s alerts=%d",
        strategy_config_id,
        is_degrading,
        len(alerts),
    )
    return {
        "is_degrading": is_degrading,
        "alerts": alerts,
        "health_trend": health_trend,
    }


def _severity_from_decline(decline: float) -> str:
    """Map score decline amount to severity."""
    if decline > 30:
        return "CRITICAL"
    elif decline > 20:
        return "HIGH"
    elif decline > 10:
        return "MEDIUM"
    return "LOW"


def _worst_severity(alerts: list[dict]) -> str:
    """Return the worst severity from a list of alert dicts."""
    order = {"LOW": 0, "MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}
    worst = "LOW"
    for a in alerts:
        if order.get(a.get("severity", "LOW"), 0) > order.get(worst, 0):
            worst = a["severity"]
    return worst


def _alert_to_dict(alert) -> dict:
    """Convert a DegradationAlert ORM object to a dict."""
    return {
        "id": str(alert.id),
        "tenant_id": str(alert.tenant_id),
        "strategy_config_id": str(alert.strategy_config_id),
        "portfolio_id": str(alert.portfolio_id),
        "alert_type": alert.alert_type,
        "severity": alert.severity,
        "details": alert.details,
        "auto_action_taken": alert.auto_action_taken,
        "acknowledged": alert.acknowledged,
        "created_at": alert.created_at,
    }
