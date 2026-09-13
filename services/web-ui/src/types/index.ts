/**
 * TypeScript interfaces mirroring the backend Pydantic schemas
 * (`services/api-gateway/app/schemas.py`).
 *
 * Conventions:
 * - UUID fields are `string` (serialized by the API).
 * - Datetime fields are `string` (ISO 8601 from JSON).
 * - Numeric fields are `number`.
 * - `dict` maps to `Record<string, unknown>`.
 * - Response interfaces are `readonly`; request interfaces are mutable.
 * - Request fields with Pydantic defaults are optional; nullable fields
 *   (`| None`) accept `null`.
 */

// --- Auth ---
export interface LoginRequest {
  email: string;
  password: string;
}

export interface TokenResponse {
  readonly access_token: string;
  readonly token_type: string;
}

export interface BootstrapRequest {
  email: string;
  password: string;
}

// --- Tenant ---
export interface TenantCreate {
  name: string;
  default_currency?: string;
  subscription_plan?: string;
}

export interface TenantUpdate {
  name?: string | null;
  status?: string | null;
  default_currency?: string | null;
  subscription_plan?: string | null;
  risk_profile?: Record<string, unknown> | null;
  resource_limits?: Record<string, unknown> | null;
  features_enabled?: unknown[] | null;
}

export interface TenantResponse {
  readonly id: string;
  readonly name: string;
  readonly status: string;
  readonly subscription_plan: string;
  readonly default_currency: string;
  readonly risk_profile: Record<string, unknown> | null;
  readonly resource_limits: Record<string, unknown> | null;
  readonly features_enabled: unknown[] | null;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- User ---
export interface UserCreate {
  email: string;
  password: string;
  role?: string;
}

export interface UserUpdate {
  role?: string | null;
  is_active?: boolean | null;
}

export interface UserResponse {
  readonly id: string;
  readonly tenant_id: string | null;
  readonly email: string;
  readonly role: string;
  readonly is_active: boolean;
  readonly created_at: string;
}

// --- Portfolio ---
export interface PortfolioCreate {
  name: string;
  starting_capital?: number;
  trading_mode?: string;
}

export interface PortfolioUpdate {
  name?: string | null;
  trading_mode?: string | null;
}

export interface PortfolioResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly name: string;
  readonly starting_capital: number;
  readonly current_equity: number;
  readonly cash: number;
  readonly trading_mode: string;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Audit ---
export interface AuditEventResponse {
  readonly id: string;
  readonly tenant_id: string | null;
  readonly user_id: string | null;
  readonly action: string;
  readonly resource: string | null;
  readonly before_state: Record<string, unknown> | null;
  readonly after_state: Record<string, unknown> | null;
  readonly ip_address: string | null;
  readonly created_at: string;
}

// --- OHLCV ---
export interface OHLCVBarCreate {
  symbol: string;
  exchange: string;
  timeframe: string;
  timestamp: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface OHLCVBarBulkCreate {
  bars: OHLCVBarCreate[];
}

export interface OHLCVBarResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly symbol: string;
  readonly exchange: string;
  readonly timeframe: string;
  readonly timestamp: string;
  readonly open: number;
  readonly high: number;
  readonly low: number;
  readonly close: number;
  readonly volume: number;
  readonly created_at: string;
}

// --- Strategy ---
export interface StrategyCreate {
  name: string;
  version?: string;
  strategy_type: string;
  description?: string | null;
}

export interface StrategyUpdate {
  description?: string | null;
  is_active?: boolean | null;
}

export interface StrategyResponse {
  readonly id: string;
  readonly tenant_id: string | null;
  readonly name: string;
  readonly version: string;
  readonly strategy_type: string;
  readonly description: string | null;
  readonly is_active: boolean;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- StrategyConfig ---
export interface StrategyConfigCreate {
  strategy_id: string;
  portfolio_id: string;
  parameters?: Record<string, unknown>;
}

export interface StrategyConfigUpdate {
  parameters?: Record<string, unknown> | null;
  lifecycle_status?: string | null;
}

export interface StrategyConfigResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly strategy_id: string;
  readonly portfolio_id: string;
  readonly parameters: Record<string, unknown>;
  readonly lifecycle_status: string;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Backtest ---
export interface BacktestCreate {
  strategy_config_id: string;
  symbol: string;
  exchange?: string;
  timeframe?: string;
  start_date: string;
  end_date: string;
  parameters?: Record<string, unknown>;
}

export interface BacktestResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly strategy_config_id: string;
  readonly symbol: string;
  readonly exchange: string;
  readonly timeframe: string;
  readonly status: string;
  readonly start_date: string;
  readonly end_date: string;
  readonly parameters: Record<string, unknown>;
  readonly metrics: Record<string, unknown> | null;
  readonly error_message: string | null;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- RiskPolicy ---
export interface RiskPolicyCreate {
  name: string;
  portfolio_id?: string | null;
  policy_type?: string;
  max_daily_loss_pct?: number | null;
  max_drawdown_pct?: number | null;
  max_position_pct?: number | null;
  max_order_value?: number | null;
  max_leverage?: number | null;
  allowed_instruments?: string[] | null;
  trading_windows?: Record<string, unknown> | null;
}

export interface RiskPolicyUpdate {
  name?: string | null;
  portfolio_id?: string | null;
  policy_type?: string | null;
  max_daily_loss_pct?: number | null;
  max_drawdown_pct?: number | null;
  max_position_pct?: number | null;
  max_order_value?: number | null;
  max_leverage?: number | null;
  allowed_instruments?: string[] | null;
  trading_windows?: Record<string, unknown> | null;
}

export interface RiskPolicyResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly name: string;
  readonly portfolio_id: string | null;
  readonly policy_type: string;
  readonly max_daily_loss_pct: number | null;
  readonly max_drawdown_pct: number | null;
  readonly max_position_pct: number | null;
  readonly max_order_value: number | null;
  readonly max_leverage: number | null;
  readonly allowed_instruments: string[] | null;
  readonly trading_windows: Record<string, unknown> | null;
  readonly is_active: boolean;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Position ---
export interface PositionResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly symbol: string;
  readonly exchange: string;
  readonly quantity: number;
  readonly avg_entry_price: number;
  readonly current_price: number | null;
  readonly unrealized_pnl: number | null;
  readonly realized_pnl: number;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Order ---
export interface OrderCreate {
  portfolio_id: string;
  symbol: string;
  exchange?: string;
  side: string;
  order_type?: string;
  quantity: number;
  price?: number | null;
}

export interface OrderResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly symbol: string;
  readonly exchange: string;
  readonly side: string;
  readonly order_type: string;
  readonly quantity: number;
  readonly price: number | null;
  readonly filled_quantity: number;
  readonly avg_fill_price: number | null;
  readonly status: string;
  readonly reject_reason: string | null;
  readonly source: string;
  readonly broker_account_id: string | null;
  readonly risk_decision: Record<string, unknown> | null;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Signal ---
export interface SignalResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly strategy_config_id: string;
  readonly symbol: string;
  readonly exchange: string;
  readonly signal_value: number;
  readonly confidence: number;
  readonly expected_return: number | null;
  readonly expected_volatility: number | null;
  readonly horizon: string | null;
  readonly stop_price: number | null;
  readonly target_price: number | null;
  readonly created_at: string;
}

// --- TradeIntent ---
export interface TradeIntentResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly signal_id: string | null;
  readonly symbol: string;
  readonly exchange: string;
  readonly side: string;
  readonly target_quantity: number;
  readonly target_value: number | null;
  readonly status: string;
  readonly risk_evaluation: Record<string, unknown> | null;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- PortfolioDashboard ---
export interface PortfolioDashboard {
  readonly portfolio_id: string;
  readonly portfolio_name: string;
  readonly trading_mode: string;
  readonly starting_capital: number;
  readonly current_equity: number;
  readonly cash: number;
  readonly total_pnl: number;
  readonly daily_pnl: number;
  readonly positions_count: number;
  readonly open_orders_count: number;
  readonly risk_status: string;
}

// --- BrokerAccount ---
export interface BrokerAccountCreate {
  broker_type: string;
  display_name: string;
  credentials?: Record<string, unknown> | null;
  credential_metadata?: Record<string, unknown> | null;
  is_primary?: boolean;
}

export interface BrokerAccountUpdate {
  display_name?: string | null;
  credentials?: Record<string, unknown> | null;
  credential_metadata?: Record<string, unknown> | null;
  status?: string | null;
  is_primary?: boolean | null;
}

export interface BrokerAccountResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly broker_type: string;
  readonly display_name: string;
  readonly credential_metadata: Record<string, unknown> | null;
  readonly status: string;
  readonly is_primary: boolean;
  readonly created_at: string;
  readonly updated_at: string;
}

// --- Execution ---
export interface ExecutionRequest {
  portfolio_id: string;
  broker_account_id: string;
  symbol: string;
  exchange?: string;
  side: "BUY" | "SELL";
  order_type?: string;
  quantity: number;
  price?: number | null;
}

export interface ExecutionResponse {
  readonly order_id: string;
  readonly broker_account_id: string;
  readonly status: string;
  readonly filled_quantity: number;
  readonly avg_fill_price: number | null;
  readonly reject_reason: string | null;
  readonly risk_decision: Record<string, unknown> | null;
  readonly created_at: string;
}

// --- KillSwitch ---
export interface KillSwitchAction {
  scope: string;
  target_id?: string | null;
  action: "HALT" | "RESUME";
  reason?: string | null;
}

export interface KillSwitchStatus {
  readonly tenant_halted: boolean;
  readonly portfolios_halted: string[];
  readonly broker_accounts_halted: string[];
}

// --- Reconciliation ---
export interface ReconciliationResult {
  readonly broker_account_id: string;
  readonly status: string;
  readonly matched_positions: number;
  readonly mismatched_positions: number;
  readonly internal_only: Record<string, unknown>[];
  readonly broker_only: Record<string, unknown>[];
  readonly mismatches: Record<string, unknown>[];
  readonly reconciled_at: string;
}

// --- Market Regime (Phase 5) ---
export interface RegimeComputeRequest {
  symbol: string;
  exchange?: string;
  timeframe?: string;
  lookback_bars?: number;
}

export interface MarketRegimeResponse {
  readonly id: string;
  readonly regime_label: string;
  readonly features: Record<string, unknown> | null;
  readonly confidence: number;
  readonly symbol: string;
  readonly exchange: string;
  readonly timeframe: string;
  readonly computed_at: string;
  readonly created_at: string;
}

// --- Strategy Health (Phase 5) ---
export interface HealthEvaluateRequest {
  strategy_config_id: string;
  portfolio_id: string;
}

export interface StrategyHealthResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly strategy_config_id: string;
  readonly portfolio_id: string;
  readonly win_rate: number;
  readonly avg_return: number;
  readonly sharpe_ratio: number | null;
  readonly max_drawdown: number | null;
  readonly total_trades: number;
  readonly recent_pnl: number;
  readonly health_score: number;
  readonly health_status: string;
  readonly evaluated_at: string;
  readonly created_at: string;
}

// --- AI Decision (Phase 5) ---
export interface AllocationRequest {
  portfolio_id: string;
  mode?: "LIVE" | "SHADOW";
}

export interface AIDecisionResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly market_regime_id: string | null;
  readonly strategy_weights: Record<string, unknown>;
  readonly cash_weight: number;
  readonly confidence: number;
  readonly mode: string;
  readonly reward_params: Record<string, unknown> | null;
  readonly context_snapshot: Record<string, unknown> | null;
  readonly explanation: string | null;
  readonly created_at: string;
}

// --- Shadow Result (Phase 5) ---
export interface ShadowResultCreate {
  ai_decision_id: string;
  strategy_config_id: string;
  hypothetical_return: number;
  actual_return: number;
  evaluation_start: string;
  evaluation_end: string;
}

export interface ShadowResultResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly ai_decision_id: string;
  readonly strategy_config_id: string;
  readonly hypothetical_return: number;
  readonly actual_return: number;
  readonly evaluation_start: string;
  readonly evaluation_end: string;
  readonly created_at: string;
}

// --- LLM Supervisor (Phase 6) ---
export interface SupervisorRecommendRequest {
  portfolio_id: string;
  decision_id?: string | null;
}

export interface SupervisorActionResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly portfolio_id: string;
  readonly decision_id: string | null;
  readonly action_type: string;
  readonly recommendation: Record<string, unknown>;
  readonly reasoning: string | null;
  readonly confidence: number;
  readonly status: string;
  readonly created_at: string;
}

// --- News (Phase 6) ---
export interface NewsItemCreate {
  headline: string;
  source?: string | null;
  url?: string | null;
  symbols?: string[];
  sentiment_score: number;
  sentiment_label: "POSITIVE" | "NEGATIVE" | "NEUTRAL";
  published_at: string;
}

export interface NewsItemResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly headline: string;
  readonly source: string | null;
  readonly url: string | null;
  readonly symbols: string[] | null;
  readonly sentiment_score: number;
  readonly sentiment_label: string;
  readonly published_at: string;
  readonly created_at: string;
}

// --- Counterfactual (Phase 6) ---
export interface CounterfactualRequest {
  ai_decision_id: string;
  evaluation_start: string;
  evaluation_end: string;
}

export interface CounterfactualComparisonItem {
  readonly strategy_config_id: string;
  readonly strategy_name: string;
  readonly was_chosen: boolean;
  readonly weight: number;
  readonly hypothetical_return: number;
}

export interface CounterfactualResponse {
  readonly ai_decision_id: string;
  readonly actual_weighted_return: number;
  readonly best_alternative_return: number;
  readonly regret: number;
  readonly comparisons: CounterfactualComparisonItem[];
  readonly evaluation_start: string;
  readonly evaluation_end: string;
}

// --- Reward / Adaptive Allocation (Phase 6) ---
export interface RewardRequest {
  portfolio_id: string;
  arm_name: string;
  reward: number;
}

export interface RewardResponse {
  readonly arm_name: string;
  readonly alpha: number;
  readonly beta_param: number;
  readonly total_pulls: number;
  readonly updated_at: string;
}

// --- Degradation Detection (Phase 6) ---
export interface DegradationCheckRequest {
  strategy_config_id: string;
  portfolio_id: string;
  auto_demote?: boolean;
}

export interface DegradationAlertResponse {
  readonly id: string;
  readonly tenant_id: string;
  readonly strategy_config_id: string;
  readonly portfolio_id: string;
  readonly alert_type: string;
  readonly severity: string;
  readonly details: Record<string, unknown> | null;
  readonly auto_action_taken: string | null;
  readonly acknowledged: boolean;
  readonly created_at: string;
}

export interface DegradationCheckResponse {
  readonly is_degrading: boolean;
  readonly alerts: DegradationAlertResponse[];
  readonly health_trend: number[];
}
