"""Pydantic request/response schemas for Phase 1 APIs."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, model_validator


# --- Auth ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class BootstrapRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


# --- Tenant ---
class TenantCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    default_currency: str = Field(default="INR", max_length=3)
    subscription_plan: str = Field(default="FREE", max_length=50)


class TenantUpdate(BaseModel):
    name: str | None = None
    status: str | None = None
    default_currency: str | None = None
    subscription_plan: str | None = None
    risk_profile: dict | None = None
    resource_limits: dict | None = None
    features_enabled: list | None = None


class TenantResponse(BaseModel):
    id: uuid.UUID
    name: str
    status: str
    subscription_plan: str
    default_currency: str
    risk_profile: dict | None = None
    resource_limits: dict | None = None
    features_enabled: list | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- User ---
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    role: str = Field(default="VIEWER")


class UserUpdate(BaseModel):
    role: str | None = None
    is_active: bool | None = None


class UserResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    email: str
    role: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Portfolio ---
class PortfolioCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    starting_capital: float = Field(default=0, ge=0)
    trading_mode: str = Field(default="PAPER")


class PortfolioUpdate(BaseModel):
    name: str | None = None
    trading_mode: str | None = None


class PortfolioResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    starting_capital: float
    current_equity: float
    cash: float
    trading_mode: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Audit ---
class AuditEventResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    user_id: uuid.UUID | None
    action: str
    resource: str | None
    before_state: dict | None
    after_state: dict | None
    ip_address: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- OHLCV ---
class OHLCVBarCreate(BaseModel):
    symbol: str = Field(max_length=50)
    exchange: str = Field(max_length=20)
    timeframe: str = Field(max_length=10)
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


class OHLCVBarBulkCreate(BaseModel):
    bars: list[OHLCVBarCreate]


class OHLCVBarResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    symbol: str
    exchange: str
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Strategy ---
class StrategyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    version: str = "1.0"
    strategy_type: str = Field(min_length=1, max_length=50)
    description: str | None = None


class StrategyUpdate(BaseModel):
    description: str | None = None
    is_active: bool | None = None


class StrategyResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    name: str
    version: str
    strategy_type: str
    description: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- StrategyConfig ---
class StrategyConfigCreate(BaseModel):
    strategy_id: uuid.UUID
    portfolio_id: uuid.UUID
    parameters: dict = Field(default_factory=dict)


class StrategyConfigUpdate(BaseModel):
    parameters: dict | None = None
    lifecycle_status: str | None = None


class StrategyConfigResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    strategy_id: uuid.UUID
    portfolio_id: uuid.UUID
    parameters: dict
    lifecycle_status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Backtest ---
class BacktestCreate(BaseModel):
    strategy_config_id: uuid.UUID
    symbol: str = Field(max_length=50)
    exchange: str = Field(default="NSE", max_length=20)
    timeframe: str = Field(default="1d", max_length=10)
    start_date: datetime
    end_date: datetime
    parameters: dict = Field(default_factory=dict)


class BacktestResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_config_id: uuid.UUID
    symbol: str
    exchange: str
    timeframe: str
    status: str
    start_date: datetime
    end_date: datetime
    parameters: dict
    metrics: dict | None
    error_message: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- RiskPolicy ---
class RiskPolicyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    portfolio_id: uuid.UUID | None = None
    policy_type: str = Field(default="TENANT", max_length=30)
    max_daily_loss_pct: float | None = None
    max_drawdown_pct: float | None = None
    max_position_pct: float | None = None
    max_order_value: float | None = None
    max_leverage: float | None = Field(default=1.0)
    allowed_instruments: list[str] | None = None
    trading_windows: dict | None = None


class RiskPolicyUpdate(BaseModel):
    name: str | None = None
    portfolio_id: uuid.UUID | None = None
    policy_type: str | None = None
    max_daily_loss_pct: float | None = None
    max_drawdown_pct: float | None = None
    max_position_pct: float | None = None
    max_order_value: float | None = None
    max_leverage: float | None = None
    allowed_instruments: list[str] | None = None
    trading_windows: dict | None = None


class RiskPolicyResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    portfolio_id: uuid.UUID | None = None
    policy_type: str = Field(default="TENANT", max_length=30)
    max_daily_loss_pct: float | None = None
    max_drawdown_pct: float | None = None
    max_position_pct: float | None = None
    max_order_value: float | None = None
    max_leverage: float | None = Field(default=1.0)
    allowed_instruments: list[str] | None = None
    trading_windows: dict | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Position ---
class PositionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    symbol: str
    exchange: str
    quantity: float
    avg_entry_price: float
    current_price: float | None
    unrealized_pnl: float | None
    realized_pnl: float
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Order ---
class OrderCreate(BaseModel):
    portfolio_id: uuid.UUID
    symbol: str = Field(max_length=50)
    exchange: str = Field(default="NSE", max_length=20)
    side: str = Field(max_length=10)
    order_type: str = Field(default="MARKET", max_length=20)
    quantity: float = Field(gt=0)
    price: float | None = None


class OrderResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    symbol: str
    exchange: str
    side: str
    order_type: str
    quantity: float
    price: float | None
    filled_quantity: float
    avg_fill_price: float | None
    status: str
    reject_reason: str | None
    source: str
    broker_account_id: uuid.UUID | None = None
    risk_decision: dict | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Signal ---
class SignalResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_config_id: uuid.UUID
    symbol: str
    exchange: str
    signal_value: float
    confidence: float
    expected_return: float | None
    expected_volatility: float | None
    horizon: str | None
    stop_price: float | None
    target_price: float | None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- TradeIntent ---
class TradeIntentResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    signal_id: uuid.UUID | None
    symbol: str
    exchange: str
    side: str
    target_quantity: float
    target_value: float | None
    status: str
    risk_evaluation: dict | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- PortfolioDashboard ---
class PortfolioDashboard(BaseModel):
    portfolio_id: uuid.UUID
    portfolio_name: str
    trading_mode: str
    starting_capital: float
    current_equity: float
    cash: float
    total_pnl: float
    daily_pnl: float
    positions_count: int
    open_orders_count: int
    risk_status: str


# --- BrokerAccount ---
class BrokerAccountCreate(BaseModel):
    broker_type: str = Field(max_length=30)
    display_name: str = Field(min_length=1, max_length=255)
    credentials: dict | None = None
    credential_metadata: dict | None = None
    is_primary: bool = False


class BrokerAccountUpdate(BaseModel):
    display_name: str | None = None
    credentials: dict | None = None
    credential_metadata: dict | None = None
    status: str | None = None
    is_primary: bool | None = None


class BrokerAccountResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    broker_type: str
    display_name: str
    credential_metadata: dict | None = None
    status: str
    is_primary: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Execution ---
class ExecutionRequest(BaseModel):
    portfolio_id: uuid.UUID
    broker_account_id: uuid.UUID
    symbol: str = Field(max_length=50)
    exchange: str = Field(default="NSE", max_length=20)
    side: str = Field(max_length=10, pattern="^(BUY|SELL)$")
    order_type: str = Field(default="MARKET", max_length=20)
    quantity: float = Field(gt=0)
    price: float | None = None


class ExecutionResponse(BaseModel):
    order_id: uuid.UUID
    broker_account_id: uuid.UUID
    status: str
    filled_quantity: float
    avg_fill_price: float | None
    reject_reason: str | None = None
    risk_decision: dict | None = None
    created_at: datetime


# --- KillSwitch ---
class KillSwitchAction(BaseModel):
    scope: str
    target_id: uuid.UUID | None = None
    action: str = Field(pattern="^(HALT|RESUME)$")
    reason: str | None = None


class KillSwitchStatus(BaseModel):
    tenant_halted: bool
    portfolios_halted: list[uuid.UUID] = Field(default_factory=list)
    broker_accounts_halted: list[uuid.UUID] = Field(default_factory=list)


# --- Reconciliation ---
class ReconciliationResult(BaseModel):
    broker_account_id: uuid.UUID
    status: str
    matched_positions: int = 0
    mismatched_positions: int = 0
    internal_only: list[dict] = Field(default_factory=list)
    broker_only: list[dict] = Field(default_factory=list)
    mismatches: list[dict] = Field(default_factory=list)
    reconciled_at: datetime


# --- Market Regime (Phase 5) ---
class RegimeComputeRequest(BaseModel):
    symbol: str = Field(max_length=50)
    exchange: str = Field(default="NSE", max_length=20)
    timeframe: str = Field(default="1d", max_length=10)
    lookback_bars: int = Field(default=50, ge=10, le=500)


class MarketRegimeResponse(BaseModel):
    id: uuid.UUID
    regime_label: str
    features: dict | None = None
    confidence: float
    symbol: str
    exchange: str
    timeframe: str
    computed_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Strategy Health (Phase 5) ---
class HealthEvaluateRequest(BaseModel):
    strategy_config_id: uuid.UUID
    portfolio_id: uuid.UUID


class StrategyHealthResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    strategy_config_id: uuid.UUID
    portfolio_id: uuid.UUID
    win_rate: float
    avg_return: float
    sharpe_ratio: float | None = None
    max_drawdown: float | None = None
    total_trades: int
    recent_pnl: float
    health_score: float
    health_status: str
    evaluated_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


# --- AI Decision (Phase 5) ---
class AllocationRequest(BaseModel):
    portfolio_id: uuid.UUID
    mode: str = Field(default="LIVE", pattern="^(LIVE|SHADOW)$")


class AIDecisionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    market_regime_id: uuid.UUID | None = None
    strategy_weights: dict
    cash_weight: float
    confidence: float
    mode: str
    reward_params: dict | None = None
    context_snapshot: dict | None = None
    explanation: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Shadow Result (Phase 5) ---
class ShadowResultCreate(BaseModel):
    ai_decision_id: uuid.UUID
    strategy_config_id: uuid.UUID
    hypothetical_return: float
    actual_return: float
    evaluation_start: datetime
    evaluation_end: datetime

    @model_validator(mode="after")
    def _check_interval(self) -> ShadowResultCreate:
        start = self.evaluation_start
        end = self.evaluation_end
        # Reject mixed naive/aware comparisons
        if (start.tzinfo is None) != (end.tzinfo is None):
            msg = "evaluation_start and evaluation_end must both be timezone-aware or both naive"
            raise ValueError(msg)
        if end <= start:
            msg = "evaluation_end must be after evaluation_start"
            raise ValueError(msg)
        return self


class ShadowResultResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    ai_decision_id: uuid.UUID
    strategy_config_id: uuid.UUID
    hypothetical_return: float
    actual_return: float
    evaluation_start: datetime
    evaluation_end: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
