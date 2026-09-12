"""Deterministic risk manager: policy evaluation, position sizing, daily governor."""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from enum import Enum

from sqlalchemy import or_
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class RiskStatus(str, Enum):
    NORMAL = "NORMAL"
    CAUTIOUS = "CAUTIOUS"
    REDUCED_RISK = "REDUCED_RISK"
    HALTED = "HALTED"


@dataclass
class RiskDecision:
    approved: bool
    status: RiskStatus
    approved_quantity: float
    reason: str
    policy_id: uuid.UUID | None = None


class RiskEvaluator:
    """Evaluates orders against active risk policies and the daily risk governor."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def evaluate_order(
        self,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        symbol: str,
        side: str,
        quantity: float,
        price: float,
    ) -> RiskDecision:
        from app.models import RiskPolicy  # lazy import to avoid circular imports

        policies = (
            self.db.query(RiskPolicy)
            .filter(
                RiskPolicy.tenant_id == tenant_id,
                RiskPolicy.is_active.is_(True),
                or_(
                    RiskPolicy.portfolio_id.is_(None),
                    RiskPolicy.portfolio_id == portfolio_id,
                ),
            )
            .all()
        )

        if not policies:
            return RiskDecision(
                approved=True,
                status=RiskStatus.NORMAL,
                approved_quantity=quantity,
                reason="No active risk policies — permissive default",
                policy_id=None,
            )

        status = self._get_risk_status(tenant_id, portfolio_id)

        if status == RiskStatus.HALTED:
            return RiskDecision(
                approved=False,
                status=status,
                approved_quantity=0.0,
                reason="Trading halted — daily loss limit exceeded",
            )

        if status == RiskStatus.REDUCED_RISK and side.upper() == "BUY":
            return RiskDecision(
                approved=False,
                status=status,
                approved_quantity=0.0,
                reason="Reduced risk — only closing/sell orders permitted",
            )

        approved_quantity = float(quantity)
        constraining_policy_id: uuid.UUID | None = None
        reasons: list[str] = []

        for policy in policies:
            if price <= 0:
                return RiskDecision(
                    approved=False,
                    status=status,
                    approved_quantity=0.0,
                    reason="Price must be positive",
                    policy_id=policy.id,
                )

            # Max order value check
            if policy.max_order_value is not None:
                order_value = price * approved_quantity
                if order_value > float(policy.max_order_value):
                    approved_quantity = float(policy.max_order_value) / price
                    constraining_policy_id = policy.id
                    reasons.append(
                        f"Reduced to max_order_value={policy.max_order_value}"
                    )

            # Max position pct check (fraction of portfolio equity)
            if policy.max_position_pct is not None:
                from app.models import Portfolio  # lazy import

                portfolio = (
                    self.db.query(Portfolio)
                    .filter(
                        Portfolio.id == portfolio_id,
                        Portfolio.tenant_id == tenant_id,
                    )
                    .first()
                )
                equity = float(portfolio.current_equity) if portfolio else 0.0
                if equity > 0:
                    max_value = float(policy.max_position_pct) * equity
                    order_value = price * approved_quantity
                    if order_value > max_value:
                        approved_quantity = max_value / price
                        constraining_policy_id = policy.id
                        reasons.append(
                            f"Reduced to max_position_pct={policy.max_position_pct} of equity"
                        )

        if approved_quantity <= 0:
            return RiskDecision(
                approved=False,
                status=status,
                approved_quantity=0.0,
                reason="Position sizing reduced quantity to zero",
                policy_id=constraining_policy_id,
            )

        reason = "Approved" if not reasons else "; ".join(reasons)
        logger.info(
            "Risk approved %s %s qty=%s approved=%s (%s)",
            side, symbol, quantity, approved_quantity, reason,
        )
        return RiskDecision(
            approved=True,
            status=status,
            approved_quantity=approved_quantity,
            reason=reason,
            policy_id=constraining_policy_id,
        )

    def get_portfolio_risk_status(
        self, tenant_id: uuid.UUID, portfolio_id: uuid.UUID
    ) -> RiskStatus:
        """Public wrapper for dashboard endpoints."""
        return self._get_risk_status(tenant_id, portfolio_id)

    def _get_risk_status(
        self, tenant_id: uuid.UUID, portfolio_id: uuid.UUID
    ) -> RiskStatus:
        from app.models import Portfolio, RiskPolicy  # lazy imports

        portfolio = (
            self.db.query(Portfolio)
            .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
            .first()
        )
        if portfolio is None:
            logger.warning(
                "Portfolio %s not found for tenant %s; reporting NORMAL",
                portfolio_id, tenant_id,
            )
            return RiskStatus.NORMAL

        policies = (
            self.db.query(RiskPolicy)
            .filter(
                RiskPolicy.tenant_id == tenant_id,
                RiskPolicy.is_active.is_(True),
                or_(
                    RiskPolicy.portfolio_id.is_(None),
                    RiskPolicy.portfolio_id == portfolio_id,
                ),
            )
            .all()
        )

        thresholds = [p for p in policies if p.max_daily_loss_pct is not None]
        if not thresholds:
            return RiskStatus.NORMAL

        # Strictest policy = smallest max_daily_loss_pct (trips governor earliest)
        policy = min(thresholds, key=lambda p: float(p.max_daily_loss_pct))
        max_loss = float(policy.max_daily_loss_pct)

        total_pnl = float(portfolio.current_equity) - float(portfolio.starting_capital)

        starting_capital = float(portfolio.starting_capital)
        pnl_pct = total_pnl / starting_capital if starting_capital > 0 else 0.0

        if pnl_pct > -max_loss * 0.5:
            status = RiskStatus.NORMAL
        elif pnl_pct > -max_loss:
            status = RiskStatus.CAUTIOUS
        elif pnl_pct > -max_loss * 1.5:
            status = RiskStatus.REDUCED_RISK
        else:
            status = RiskStatus.HALTED

        logger.info(
            "Risk status for portfolio %s: %s (pnl_pct=%.4f, max_loss=%.4f, policy=%s)",
            portfolio_id, status.value, pnl_pct, max_loss, policy.id,
        )
        return status
