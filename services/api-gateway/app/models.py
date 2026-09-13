"""SQLAlchemy ORM models for Phase 1: tenants, users, portfolios, audit."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    LargeBinary,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _new_uuid() -> uuid.UUID:
    return uuid.uuid4()


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    name: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ACTIVE")
    subscription_plan: Mapped[str] = mapped_column(
        String(50), nullable=False, default="FREE"
    )
    default_currency: Mapped[str] = mapped_column(
        String(3), nullable=False, default="INR"
    )
    risk_profile: Mapped[dict | None] = mapped_column(JSON, default=dict)
    resource_limits: Mapped[dict | None] = mapped_column(JSON, default=dict)
    features_enabled: Mapped[list | None] = mapped_column(JSON, default=list)
    trading_halted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )

    users: Mapped[list[User]] = relationship(back_populates="tenant")
    portfolios: Mapped[list[Portfolio]] = relationship(back_populates="tenant")
    strategies: Mapped[list[Strategy]] = relationship()
    strategy_configs: Mapped[list[StrategyConfig]] = relationship()
    backtest_runs: Mapped[list[BacktestRun]] = relationship()
    risk_policies: Mapped[list[RiskPolicy]] = relationship()
    positions: Mapped[list[Position]] = relationship()
    orders: Mapped[list[Order]] = relationship()
    broker_accounts: Mapped[list[BrokerAccount]] = relationship()
    ai_decisions: Mapped[list[AIDecision]] = relationship()
    shadow_results: Mapped[list[ShadowResult]] = relationship()
    news_items: Mapped[list[NewsItem]] = relationship()
    llm_supervisor_actions: Mapped[list[LLMSupervisorAction]] = relationship()
    degradation_alerts: Mapped[list[DegradationAlert]] = relationship()
    bandit_arm_states: Mapped[list[BanditArmState]] = relationship()


class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("email", name="uq_user_email"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=True
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )

    tenant: Mapped[Tenant | None] = relationship(back_populates="users")


class Portfolio(Base):
    __tablename__ = "portfolios"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    starting_capital: Mapped[float] = mapped_column(Numeric(20, 2), default=0)
    current_equity: Mapped[float] = mapped_column(Numeric(20, 2), default=0)
    cash: Mapped[float] = mapped_column(Numeric(20, 2), default=0)
    trading_mode: Mapped[str] = mapped_column(
        String(20), nullable=False, default="PAPER"
    )
    trading_halted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )

    tenant: Mapped[Tenant] = relationship(back_populates="portfolios")


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    resource: Mapped[str | None] = mapped_column(String(255))
    before_state: Mapped[dict | None] = mapped_column(JSON)
    after_state: Mapped[dict | None] = mapped_column(JSON)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class OHLCVBar(Base):
    __tablename__ = "ohlcv_bars"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id",
            "symbol",
            "exchange",
            "timeframe",
            "timestamp",
            name="uq_ohlcv_bar",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False)
    timeframe: Mapped[str] = mapped_column(String(10), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    open: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    high: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    low: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    close: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    volume: Mapped[float] = mapped_column(Numeric(20, 0), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class Strategy(Base):
    __tablename__ = "strategies"
    __table_args__ = (
        UniqueConstraint("tenant_id", "name", "version", name="uq_strategy_version"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    version: Mapped[str] = mapped_column(String(50), nullable=False, default="1.0")
    strategy_type: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class StrategyConfig(Base):
    __tablename__ = "strategy_configs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    strategy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategies.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    parameters: Mapped[dict | None] = mapped_column(JSON, default=dict)
    lifecycle_status: Mapped[str] = mapped_column(
        String(30), nullable=False, default="DEVELOPMENT"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class BacktestRun(Base):
    __tablename__ = "backtest_runs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    strategy_config_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategy_configs.id"), nullable=False
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    timeframe: Mapped[str] = mapped_column(String(10), nullable=False, default="1d")
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PENDING")
    start_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    parameters: Mapped[dict | None] = mapped_column(JSON, default=dict)
    metrics: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class RiskPolicy(Base):
    __tablename__ = "risk_policies"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    policy_type: Mapped[str] = mapped_column(
        String(30), nullable=False, default="TENANT"
    )
    max_daily_loss_pct: Mapped[float | None] = mapped_column(
        Numeric(10, 4), nullable=True
    )
    max_drawdown_pct: Mapped[float | None] = mapped_column(
        Numeric(10, 4), nullable=True
    )
    max_position_pct: Mapped[float | None] = mapped_column(
        Numeric(10, 4), nullable=True
    )
    max_order_value: Mapped[float | None] = mapped_column(Numeric(20, 2), nullable=True)
    max_leverage: Mapped[float | None] = mapped_column(
        Numeric(10, 4), nullable=True, default=1.0
    )
    allowed_instruments: Mapped[list | None] = mapped_column(JSON, nullable=True)
    trading_windows: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class Position(Base):
    __tablename__ = "positions"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "portfolio_id", "symbol", "exchange", name="uq_position"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    quantity: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False, default=0)
    avg_entry_price: Mapped[float] = mapped_column(
        Numeric(20, 4), nullable=False, default=0
    )
    current_price: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    unrealized_pnl: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    realized_pnl: Mapped[float] = mapped_column(
        Numeric(20, 4), nullable=False, default=0
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    side: Mapped[str] = mapped_column(String(10), nullable=False)
    order_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default="MARKET"
    )
    quantity: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    price: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    filled_quantity: Mapped[float] = mapped_column(
        Numeric(20, 4), nullable=False, default=0
    )
    avg_fill_price: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="NEW")
    reject_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    source: Mapped[str] = mapped_column(String(30), nullable=False, default="PAPER")
    broker_account_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("broker_accounts.id"), nullable=True
    )
    trade_intent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trade_intents.id"), nullable=True
    )
    risk_decision: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class BrokerAccount(Base):
    __tablename__ = "broker_accounts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    broker_type: Mapped[str] = mapped_column(String(30), nullable=False)
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    encrypted_credentials: Mapped[bytes | None] = mapped_column(
        LargeBinary, nullable=True
    )
    credential_metadata: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ACTIVE")
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class Signal(Base):
    __tablename__ = "signals"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    strategy_config_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategy_configs.id"), nullable=False
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    signal_value: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False)
    confidence: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False)
    expected_return: Mapped[float | None] = mapped_column(Numeric(10, 4), nullable=True)
    expected_volatility: Mapped[float | None] = mapped_column(
        Numeric(10, 4), nullable=True
    )
    horizon: Mapped[str | None] = mapped_column(String(20), nullable=True)
    stop_price: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    target_price: Mapped[float | None] = mapped_column(Numeric(20, 4), nullable=True)
    metadata_: Mapped[dict | None] = mapped_column(
        "signal_metadata", JSON, nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class TradeIntent(Base):
    __tablename__ = "trade_intents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    signal_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("signals.id"), nullable=True
    )
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    side: Mapped[str] = mapped_column(String(10), nullable=False)
    target_quantity: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False)
    target_value: Mapped[float | None] = mapped_column(Numeric(20, 2), nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PENDING")
    risk_evaluation: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class MarketRegime(Base):
    """Shared market regime classification (not tenant-scoped per PRD §28)."""

    __tablename__ = "market_regimes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    regime_label: Mapped[str] = mapped_column(String(50), nullable=False)
    features: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    confidence: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False)
    symbol: Mapped[str] = mapped_column(String(50), nullable=False)
    exchange: Mapped[str] = mapped_column(String(20), nullable=False, default="NSE")
    timeframe: Mapped[str] = mapped_column(String(10), nullable=False, default="1d")
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class StrategyHealthScore(Base):
    """Per-tenant strategy health scoring (tenant-isolated per PRD §33)."""

    __tablename__ = "strategy_health_scores"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    strategy_config_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategy_configs.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    win_rate: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False, default=0)
    avg_return: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False, default=0)
    sharpe_ratio: Mapped[float | None] = mapped_column(Numeric(10, 4), nullable=True)
    max_drawdown: Mapped[float | None] = mapped_column(Numeric(10, 4), nullable=True)
    total_trades: Mapped[int] = mapped_column(nullable=False, default=0)
    recent_pnl: Mapped[float] = mapped_column(Numeric(20, 4), nullable=False, default=0)
    health_score: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=0
    )
    health_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="HEALTHY"
    )
    evaluated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class AIDecision(Base):
    """Per-tenant AI strategy allocation decision (tenant-isolated)."""

    __tablename__ = "ai_decisions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    market_regime_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("market_regimes.id"), nullable=True
    )
    strategy_weights: Mapped[dict] = mapped_column(JSON, nullable=False)
    cash_weight: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=0
    )
    confidence: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False, default=0)
    mode: Mapped[str] = mapped_column(String(10), nullable=False, default="LIVE")
    reward_params: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    context_snapshot: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    explanation: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class ShadowResult(Base):
    """Shadow evaluation result for counterfactual analysis."""

    __tablename__ = "shadow_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    ai_decision_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("ai_decisions.id"), nullable=False
    )
    strategy_config_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategy_configs.id"), nullable=False
    )
    hypothetical_return: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=0
    )
    actual_return: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=0
    )
    evaluation_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    evaluation_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class LLMSupervisorAction(Base):
    """Audited LLM supervisor recommendation (tenant-isolated, PRD §35)."""

    __tablename__ = "llm_supervisor_actions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    decision_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("ai_decisions.id"), nullable=True
    )
    action_type: Mapped[str] = mapped_column(String(30), nullable=False)
    recommendation: Mapped[dict] = mapped_column(JSON, nullable=False)
    reasoning: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    confidence: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PENDING")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class NewsItem(Base):
    """Market news item with sentiment score (tenant-scoped)."""

    __tablename__ = "news_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    headline: Mapped[str] = mapped_column(String(500), nullable=False)
    source: Mapped[str | None] = mapped_column(String(100), nullable=True)
    url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    symbols: Mapped[list | None] = mapped_column(JSON, nullable=True)
    sentiment_score: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=0
    )
    sentiment_label: Mapped[str] = mapped_column(
        String(20), nullable=False, default="NEUTRAL"
    )
    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class BanditArmState(Base):
    """Persisted bandit arm parameters per tenant/portfolio."""

    __tablename__ = "bandit_arm_states"
    __table_args__ = (
        UniqueConstraint("tenant_id", "portfolio_id", "arm_name", name="uq_bandit_arm"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    arm_name: Mapped[str] = mapped_column(String(255), nullable=False)
    alpha: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False, default=1.0)
    beta_param: Mapped[float] = mapped_column(
        Numeric(10, 4), nullable=False, default=1.0
    )
    total_rewards: Mapped[float] = mapped_column(
        Numeric(20, 4), nullable=False, default=0
    )
    total_pulls: Mapped[int] = mapped_column(nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )


class DegradationAlert(Base):
    """Strategy degradation detection alert (tenant-isolated)."""

    __tablename__ = "degradation_alerts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=_new_uuid
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenants.id"), nullable=False
    )
    strategy_config_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("strategy_configs.id"), nullable=False
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("portfolios.id"), nullable=False
    )
    alert_type: Mapped[str] = mapped_column(String(30), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    details: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    auto_action_taken: Mapped[str | None] = mapped_column(String(50), nullable=True)
    acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
