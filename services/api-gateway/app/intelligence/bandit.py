"""Thompson Sampling contextual bandit for strategy selection."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field

import numpy as np
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


@dataclass
class BanditArm:
    """A single arm (strategy) in the bandit."""

    name: str
    alpha: float = 1.0  # Beta distribution success param
    beta: float = 1.0  # Beta distribution failure param


@dataclass
class BanditState:
    """State of the contextual bandit for a tenant/portfolio."""

    arms: list[BanditArm] = field(default_factory=list)


class ThompsonSamplingBandit:
    """Contextual multi-armed bandit using Thompson Sampling.

    Actions correspond to strategy allocations + cash.
    Context includes market regime features and strategy health scores.
    """

    def __init__(self, arms: list[str] | None = None) -> None:
        if arms is None:
            arms = ["MOMENTUM", "MEAN_REVERSION", "BREAKOUT", "CASH"]
        self.state = BanditState(arms=[BanditArm(name=name) for name in arms])

    @classmethod
    def load_or_create(
        cls,
        db: Session,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        arm_names: list[str],
    ) -> ThompsonSamplingBandit:
        """Load persisted arm state or create fresh arms.

        Args:
            db: Database session.
            tenant_id: Tenant scope.
            portfolio_id: Portfolio scope.
            arm_names: Expected arm names (creates missing ones).

        Returns:
            A ThompsonSamplingBandit with state from DB.
        """
        from app.models import BanditArmState

        bandit = cls(arms=arm_names)

        for arm in bandit.state.arms:
            db_arm = (
                db.query(BanditArmState)
                .filter(
                    BanditArmState.tenant_id == tenant_id,
                    BanditArmState.portfolio_id == portfolio_id,
                    BanditArmState.arm_name == arm.name,
                )
                .first()
            )
            if db_arm is not None:
                arm.alpha = float(db_arm.alpha)
                arm.beta = float(db_arm.beta_param)

        return bandit

    def select(
        self,
        regime_features: dict | None = None,
        health_scores: dict[str, float] | None = None,
    ) -> dict[str, float]:
        """Select strategy weights via Thompson Sampling.

        Args:
            regime_features: Market regime features (used as context).
            health_scores: Strategy name -> health score mapping.

        Returns:
            Dict of strategy_name -> weight (sums to 1.0).
        """
        samples = {}
        for arm in self.state.arms:
            # Thompson sample from Beta distribution
            sample = float(np.random.beta(arm.alpha, arm.beta))

            # Contextual adjustment: boost/penalize based on health
            if health_scores and arm.name in health_scores:
                health = health_scores[arm.name]
                # Scale health from 0-100 to 0.5-1.5 multiplier
                multiplier = 0.5 + (health / 100.0)
                sample *= multiplier

            samples[arm.name] = sample

        # Normalize to weights summing to 1.0
        total = sum(samples.values())
        if total > 0:
            weights = {k: round(v / total, 4) for k, v in samples.items()}
        else:
            n = len(self.state.arms)
            weights = {arm.name: round(1.0 / n, 4) for arm in self.state.arms}

        # Ensure weights sum to exactly 1.0 (fix rounding)
        remainder = round(1.0 - sum(weights.values()), 4)
        if remainder != 0 and weights:
            first_key = next(iter(weights))
            weights[first_key] = round(weights[first_key] + remainder, 4)

        logger.info("Bandit selected weights: %s", weights)
        return weights

    def update(self, arm_name: str, reward: float) -> None:
        """Update arm parameters based on observed reward.

        Args:
            arm_name: The arm that was pulled.
            reward: Observed reward (0-1 scale, where 1 is best).
        """
        for arm in self.state.arms:
            if arm.name == arm_name:
                # Clamp reward to [0, 1]
                r = max(0.0, min(1.0, reward))
                arm.alpha += r
                arm.beta += 1.0 - r
                logger.info(
                    "Updated arm %s: alpha=%.2f beta=%.2f",
                    arm_name,
                    arm.alpha,
                    arm.beta,
                )
                return
        logger.warning("Arm %s not found in bandit", arm_name)

    def get_confidence(self) -> float:
        """Overall confidence based on total observations."""
        total_obs = sum(arm.alpha + arm.beta - 2.0 for arm in self.state.arms)
        # Confidence grows with observations, capped at 0.95
        return round(min(0.3 + total_obs * 0.01, 0.95), 4)

    def save_state(
        self,
        db: Session,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
    ) -> None:
        """Persist current arm parameters to the database."""
        from app.models import BanditArmState

        for arm in self.state.arms:
            db_arm = (
                db.query(BanditArmState)
                .filter(
                    BanditArmState.tenant_id == tenant_id,
                    BanditArmState.portfolio_id == portfolio_id,
                    BanditArmState.arm_name == arm.name,
                )
                .first()
            )
            if db_arm is None:
                db_arm = BanditArmState(
                    tenant_id=tenant_id,
                    portfolio_id=portfolio_id,
                    arm_name=arm.name,
                    alpha=arm.alpha,
                    beta_param=arm.beta,
                    total_rewards=0,
                    total_pulls=0,
                )
                db.add(db_arm)
            else:
                db_arm.alpha = arm.alpha
                db_arm.beta_param = arm.beta
            db.flush()
