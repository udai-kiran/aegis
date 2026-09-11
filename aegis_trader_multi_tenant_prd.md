# PRD — Multi-Tenant AI-Assisted Algorithmic Trading Platform

## 1. Product Name

**Project Codename: Aegis Trader**

A multi-tenant, AI-assisted algorithmic trading and quantitative research platform supporting:

- Multiple trading strategies
- Historical backtesting
- Walk-forward testing
- Paper and shadow trading
- AI strategy selection
- Portfolio management
- Centralized deterministic risk management
- Automated execution
- Broker reconciliation
- Zerodha integration
- Docker Compose deployment

---

## 2. Executive Summary

Aegis Trader is a multi-tenant platform for developing, testing, evaluating, selecting, and executing algorithmic trading strategies.

Each tenant operates as an isolated logical trading environment with independent:

- Users
- Broker accounts
- Capital
- Portfolios
- Positions
- Orders
- Strategies
- Strategy configurations
- AI strategy allocations
- Risk policies
- Backtests
- Audit logs
- API credentials
- Data access policies

A tenant may represent:

- An individual trader
- A family account
- A proprietary trading desk
- A research team
- A company
- A fund
- An internal portfolio

The platform must guarantee that activity belonging to one tenant cannot affect another tenant's:

- Capital
- Orders
- Positions
- Broker credentials
- Risk limits
- AI decisions
- Strategy state
- Private market data
- Backtest results

Strategies analyze normalized market data and generate standardized signals.

Strategies never directly place orders.

An AI Strategy Selector determines which strategies deserve capital for a tenant based on:

- Market regime
- Strategy performance
- Strategy health
- Current signals
- Tenant portfolio state
- Tenant risk appetite
- Available capital
- Execution quality

The Portfolio Manager converts strategy opinions into target exposures.

The Risk Manager has absolute veto authority.

Only the Execution subsystem is permitted to communicate with broker order APIs.

The initial broker integration will use Zerodha Kite.

The platform will run on Docker Compose, with a future migration path to Kubernetes when multi-node high availability is required.

---

## 3. Core Product Principle

The core decision pipeline is:

```text
Market Data
     ↓
Strategy Engines
     ↓
AI Strategy Selector
     ↓
Portfolio Manager
     ↓
Risk Manager
     ↓
Execution Engine
     ↓
Broker
```

Every decision after market-data ingestion must execute within a tenant context.

Conceptually:

```text
request
  │
  ├── tenant_id
  ├── user_id
  ├── portfolio_id
  └── broker_account_id
        │
        ▼
Tenant Context
        │
        ▼
Trading Pipeline
```

No trading operation may exist without a resolved tenant context.

---

## 4. Multi-Tenant Hierarchy

The initial tenancy hierarchy should be:

```text
Platform
   │
   ├── Tenant A
   │      │
   │      ├── Users
   │      ├── Portfolios
   │      ├── Broker Accounts
   │      ├── Strategies
   │      └── Risk Policies
   │
   ├── Tenant B
   │      │
   │      ├── Users
   │      ├── Portfolios
   │      ├── Broker Accounts
   │      ├── Strategies
   │      └── Risk Policies
   │
   └── Tenant C
```

A tenant may have multiple portfolios.

Example:

```text
Tenant: Udai

├── Portfolio: Equity Intraday
├── Portfolio: Swing
├── Portfolio: Options
└── Portfolio: Experimental AI
```

Each portfolio may have different:

- Capital
- Strategies
- Risk limits
- Broker account mappings
- AI policies

---

## 5. Tenant Isolation Requirement

Tenant isolation is a hard system invariant.

The following must never occur:

```text
Tenant A signal
     ↓
Tenant B portfolio

Tenant A risk limit
     ↓
Tenant B trade

Tenant A Zerodha credentials
     ↓
Tenant B executor

Tenant A backtest
     ↓
Tenant B AI training data
```

unless explicitly permitted through a future anonymized shared-learning mechanism.

---

## 6. Multi-Tenant Data Model

All tenant-owned entities must include:

```text
tenant_id
```

Where relevant, entities should also contain:

```text
portfolio_id
broker_account_id
strategy_id
strategy_version_id
```

Examples:

```text
orders
trades
positions
signals
strategy_allocations
risk_decisions
backtest_runs
ai_decisions
portfolios
broker_accounts
strategy_configs
audit_events
```

All must be tenant scoped.

---

## 7. Tenant Entity

A tenant should contain:

```text
tenant_id
name
status
subscription_plan
created_at
default_currency
risk_profile
resource_limits
features_enabled
```

Possible tenant states:

```text
ACTIVE
SUSPENDED
READ_ONLY
DISABLED
```

A suspended tenant must not generate new live orders.

---

## 8. User and Role Model

A tenant may have multiple users.

Initial roles:

```text
TENANT_ADMIN
TRADER
RESEARCHER
RISK_MANAGER
VIEWER
```

### TENANT_ADMIN

May:

- Manage users
- Configure broker accounts
- Configure strategies
- Manage portfolios
- Configure risk policies

### TRADER

May:

- Start/stop strategies
- View signals
- Manage live trading

### RESEARCHER

May:

- Create strategies
- Run backtests
- Run experiments

Cannot enable live trading.

### RISK_MANAGER

May:

- Configure risk limits
- Halt trading
- Disable strategies

### VIEWER

Read-only.

---

## 9. Platform Administrator

Platform administrators are separate from tenant administrators.

Platform admins manage:

```text
cluster
tenant provisioning
subscriptions
resource quotas
system health
broker adapters
platform-wide incidents
```

Platform admins must not automatically receive access to decrypted broker secrets.

Credential access should follow least-privilege principles.

---

## 10. Portfolio Model

Each tenant may create multiple isolated portfolios.

A portfolio contains:

```text
portfolio_id
tenant_id
name
starting_capital
current_equity
cash
gross_exposure
net_exposure
risk_policy_id
broker_account_id
trading_mode
```

Trading modes:

```text
BACKTEST
REPLAY
PAPER
SHADOW
LIVE
```

---

## 11. Broker Account Model

A tenant may connect multiple broker accounts.

Example:

```text
Tenant A

Broker Accounts

├── Zerodha Personal
├── Zerodha Family
└── Future Broker Account
```

Each broker account contains:

```text
broker_account_id
tenant_id
broker_type
encrypted_credentials
account_metadata
status
```

---

## 12. Broker Credential Isolation

Broker credentials must never be exposed to:

```text
Strategy Engines
AI Strategy Selector
Portfolio Manager
Backtester
Frontend
```

Only the broker gateway/execution subsystem may access them.

Conceptually:

```text
Tenant A
  │
  └── Broker Credential A
          │
          ▼
       Executor A

Tenant B
  │
  └── Broker Credential B
          │
          ▼
       Executor B
```

Cross-tenant credential resolution must be impossible.

---

## 13. High-Level Architecture

```text
                         MARKET DATA
                             │
                             ▼
                    Market Data Gateway
                             │
                             ▼
                      Shared Market Bus
                             │
                             ▼
                   Tenant Orchestrator
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
       Tenant A           Tenant B           Tenant C
          │                  │                  │
          ▼                  ▼                  ▼
     Strategies          Strategies          Strategies
          │                  │                  │
          ▼                  ▼                  ▼
     AI Selector         AI Selector         AI Selector
          │                  │                  │
          ▼                  ▼                  ▼
     Portfolio           Portfolio           Portfolio
      Manager             Manager             Manager
          │                  │                  │
          ▼                  ▼                  ▼
     Risk Manager        Risk Manager        Risk Manager
          │                  │                  │
          ▼                  ▼                  ▼
     Executor            Executor            Executor
          │                  │                  │
          ▼                  ▼                  ▼
    Broker Acct A       Broker Acct B       Broker Acct C
```

Services may be physically shared while preserving logical tenant isolation.

---

## 14. Shared vs Dedicated Services

The platform should support two deployment models.

### Shared services

Suitable for most tenants.

Examples:

```text
Market Data Gateway
Feature Store
Backtest Scheduler
Strategy Runtime
AI Runtime
PostgreSQL cluster
Redis cluster
API Gateway
```

Tenant isolation happens logically.

### Dedicated execution resources

Higher-risk components may use stronger isolation:

```text
broker executor
credential access
order reconciliation
```

A future enterprise tier may support fully dedicated tenant infrastructure.

---

## 15. Core Strategy Requirement

Strategy code must not depend on environment.

The same strategy should execute unchanged for:

```text
Historical Backtest
Historical Replay
Paper Trading
Shadow Trading
Live Trading
```

Interface:

```python
class Strategy:
    def on_market_event(
        self,
        context,
        event,
        portfolio_state
    ) -> list[StrategySignal]:
        ...
```

The context contains tenant information:

```python
context.tenant_id
context.portfolio_id
context.strategy_instance_id
```

A strategy must never receive broker credentials.

---

## 16. Strategy Signal Model

Every signal contains:

```text
tenant_id
portfolio_id
strategy_id
strategy_version
instrument
timestamp
signal
confidence
expected_return
expected_volatility
horizon
stop_price
target_price
metadata
```

Signal range:

```text
-1.0 = strongest short
 0.0 = neutral
+1.0 = strongest long
```

---

## 17. Shared Strategies vs Tenant Strategies

The platform should support:

### Platform strategies

Curated strategies available to many tenants.

Example:

```text
momentum-v3
breakout-v2
mean-reversion-v4
```

### Tenant-owned strategies

Private strategies visible only to the tenant.

Example:

```text
tenant-A/custom-nifty-breakout-v7
```

Strategy code and strategy configuration must be treated separately.

---

## 18. Strategy Configuration

Different tenants may run the same strategy with different parameters.

Example:

```text
momentum-v3
```

Tenant A:

```text
lookback = 20
risk_budget = 0.25%
```

Tenant B:

```text
lookback = 50
risk_budget = 0.10%
```

Configuration must therefore be tenant scoped.

---

## 19. Strategy Lifecycle

Every strategy instance has a tenant-specific lifecycle.

```text
DEVELOPMENT
     ↓
BACKTESTED
     ↓
OUT_OF_SAMPLE_PASSED
     ↓
PAPER_TRADING
     ↓
SHADOW_TRADING
     ↓
LIVE_LOW_CAPITAL
     ↓
LIVE_FULL
```

A strategy may degrade:

```text
LIVE_FULL
     ↓
DEGRADED
     ↓
REDUCED_CAPITAL
     ↓
SHADOW_ONLY
     ↓
QUARANTINED
     ↓
DISABLED
```

One tenant disabling a strategy must not affect another tenant.

---

## 20. Initial Strategy Families

Initial platform strategies should include:

- Momentum
- Trend following
- Mean reversion
- VWAP strategies
- Breakout
- Statistical arbitrage
- Relative strength
- Pair trading
- ML-based strategies

Future:

- Options strategies
- News-driven strategies
- Sentiment strategies

---

## 21. Backtesting

Every strategy must be backtestable.

Pipeline:

```text
Historical Data
      │
      ▼
Tenant Backtest Job
      │
      ▼
Strategy
      │
      ▼
Signals
      │
      ▼
Portfolio Simulator
      │
      ▼
Risk Manager
      │
      ▼
Execution Simulator
```

No live broker communication occurs during backtests.

---

## 22. Multi-Tenant Backtest Scheduler

Backtesting may consume significant compute.

The scheduler must support:

```text
tenant quotas
priority
maximum concurrent jobs
CPU limits
memory limits
timeout limits
```

Example:

```text
Tenant A: max 5 concurrent backtests
Tenant B: max 2 concurrent backtests
```

A tenant must not exhaust cluster resources and starve other tenants.

---

## 23. Backtest Metrics

Each backtest should report:

- Gross return
- Net return
- CAGR
- Sharpe
- Sortino
- Calmar
- Maximum drawdown
- Profit factor
- Win rate
- Average winner
- Average loser
- Expected value
- Total trades
- Turnover
- Fees
- Taxes
- Slippage
- Worst day
- Best day
- Losing streak
- Capital utilization
- Exposure
- VaR
- CVaR
- Regime-specific performance

---

## 24. Backtest Reproducibility

Every result must be reproducible.

Store:

```text
tenant_id
strategy version
Git commit
configuration
dataset version
time range
cost model
execution model
random seed
risk policy version
result
```

---

## 25. Walk-Forward Testing

The platform should provide rolling train/test windows.

Example:

```text
Training: 2023 → 2024
Testing: Q1 2025
```

Then roll forward.

AI/ML models may only train on historical information available before the evaluation window.

---

## 26. Paper Trading

Paper trading consumes live market data but uses simulated execution.

Tenant pipeline:

```text
Tenant Portfolio
      │
Live Market Data
      │
Strategy
      ↓
AI Selector
      ↓
Portfolio Manager
      ↓
Risk Manager
      ↓
Paper Broker
```

---

## 27. Shadow Trading

Shadow strategies generate hypothetical trades while another strategy operates live.

This enables counterfactual evaluation.

Example:

```text
AI chose: Breakout
Actual: +0.4%
Shadow Momentum: +0.2%
Shadow Mean Reversion: -0.3%
```

Shadow results remain tenant scoped.

---

## 28. Market Regime Engine

The platform should maintain market-state features such as:

```text
trend strength
volatility
volume regime
market breadth
sector dispersion
correlation
intraday autocorrelation
gap conditions
liquidity
time-of-day regime
```

The regime engine may be shared because the underlying market is shared.

Tenant-specific portfolio information must not enter shared regime computation.

---

## 29. AI Strategy Selector

Each tenant portfolio gets an independent AI strategy allocation decision.

The AI selects:

```text
active strategies
strategy weights
capital allocation
cash allocation
strategy disablement
strategy reduction
```

The AI does not directly place orders.

---

## 30. AI Inputs

Per-tenant AI inputs include:

### Shared market context

```text
volatility
trend
breadth
liquidity
regime
sector conditions
```

### Tenant strategy context

```text
strategy performance
strategy drawdown
strategy health
current signals
historical regime performance
```

### Tenant portfolio context

```text
capital
positions
cash
gross exposure
net exposure
current P&L
drawdown
```

---

## 31. AI Output

Example:

```json
{
  "tenant_id": "tenant-a",
  "portfolio_id": "intraday",
  "market_regime": "high_volatility_trending",
  "strategy_weights": {
    "momentum": 0.40,
    "breakout": 0.35,
    "mean_reversion": 0.05,
    "cash": 0.20
  },
  "confidence": 0.82
}
```

---

## 32. Contextual Bandit

The preferred initial strategy-selection system should use a contextual multi-armed bandit.

Potential actions:

```text
Momentum
Mean Reversion
Breakout
Stat Arb
ML Strategy
Cash
```

Context includes both market state and tenant-specific strategy performance.

Candidate implementations:

- Thompson Sampling
- LinUCB
- Bayesian contextual bandits
- Neural contextual bandits

---

## 33. AI Learning Isolation

Default behavior:

**AI learning must be tenant isolated.**

Tenant A's proprietary trading results must not automatically become training data for Tenant B.

Future opt-in functionality may support anonymized, aggregated, privacy-preserving cross-tenant learning, but this is outside the MVP.

---

## 34. AI Reward Function

The AI must optimize risk-adjusted reward.

Example:

```text
reward =
    net_return
    - λ1 × drawdown
    - λ2 × volatility
    - λ3 × transaction_cost
    - λ4 × tail_risk
```

Tenant risk policy may influence λ parameters.

---

## 35. Optional LLM Supervisor

An LLM may provide supervisory context.

Available operations may include:

```text
recommend_strategy_weight()
recommend_strategy_disable()
recommend_cash_allocation()
request_position_reduction()
```

The LLM must never receive direct `place_order()` capability.

Every LLM action must include `tenant_id`, `portfolio_id`, and `decision_id`, and be audited.

---

## 36. Portfolio Manager

Each tenant portfolio has independent target positions.

Example:

```text
Tenant A
INFY target = +₹80,000

Tenant B
INFY target = -₹30,000
```

These must remain completely independent.

Strategy signals within the same portfolio may be netted.

Signals across tenants must never be netted.

---

## 37. Centralized Risk Manager

Risk logic is deterministic.

Risk has final veto authority.

The effective policy hierarchy is:

```text
Platform Safety Limits
        ↓
Tenant Risk Policy
        ↓
Portfolio Risk Policy
        ↓
Strategy Risk Limits
        ↓
Trade Approval
```

Lower levels may be stricter. They may never exceed higher-level safety ceilings.

---

## 38. Platform Risk Limits

The platform may enforce absolute limits such as:

```text
maximum order rate
maximum request size
maximum leverage
unsupported instrument types
system-wide trading halt
```

Tenants cannot override these.

---

## 39. Tenant Risk Policy

Tenant-specific settings may include:

```text
maximum daily loss
maximum drawdown
maximum portfolio exposure
maximum leverage
maximum position size
sector exposure
per-trade risk
allowed instruments
allowed trading windows
```

---

## 40. Portfolio Risk Policy

Different tenant portfolios may have different policies.

Example:

```text
Portfolio: Experimental AI
max capital: ₹1,00,000
max daily loss: 0.5%
```

while:

```text
Portfolio: Swing
max capital: ₹10,00,000
max daily loss: 1.0%
```

---

## 41. Risk-Based Position Sizing

Example:

```text
Tenant capital: ₹10,00,000
Risk/trade: 0.25%
Maximum loss: ₹2,500
Entry: ₹1,000
Stop: ₹990
Risk: ₹10/share
Maximum position: 250 shares
```

If a strategy requests 800 shares, the Risk Manager may approve only 250.

---

## 42. Daily Risk Governor

Per portfolio:

```text
NORMAL
   ↓
CAUTIOUS
   ↓
REDUCED_RISK
   ↓
HALTED
```

Illustrative configuration:

```text
P&L > -0.5%    normal sizing
P&L < -0.5%    50% sizing
P&L < -1.0%    no new positions
P&L < -1.5%    flatten and halt
```

These values must be configurable.

---

## 43. No Loss-Chasing

Risk budget must never automatically increase merely because a tenant is losing money.

Forbidden behavior:

```text
loss
 ↓
double risk
 ↓
larger loss
 ↓
double again
```

---

## 44. Operational Risk

Per tenant or broker account:

```text
stale market data      → block new orders
broker API unavailable → block new orders
broker/internal mismatch → halt account
unknown order state    → halt instrument
excessive rejects      → halt executor
risk service unavailable → fail closed
```

---

## 45. Fail-Closed Principle

When the platform cannot establish whether a new trade is safe:

```text
DO NOT TRADE
```

Examples:

- Risk service unavailable
- Tenant identity unresolved
- Broker account unresolved
- Market data stale
- Broker state uncertain

---

## 46. Execution Engine

Execution responsibilities:

- Order submission
- Modification
- Cancellation
- Idempotency
- Fill tracking
- Partial fills
- Timeout handling
- State recovery
- Broker reconciliation

Every execution request contains:

```text
tenant_id
portfolio_id
broker_account_id
trade_intent_id
risk_decision_id
```

---

## 47. Per-Broker-Account Execution Leader

Only one logical executor may actively control one broker account at a time.

Example:

```text
tenant-A
zerodha-account-1

executor-1: ACTIVE
executor-2: STANDBY
```

Leader selection should use:

- PostgreSQL advisory lock or fencing token
- Broker reconciliation

A new leader must reconcile before trading.

---

## 48. No Cross-Tenant Execution Lock

Leader election must operate at the broker-account level.

Tenant A failing over must not halt Tenant B unnecessarily.

Execution coordination key:

```text
tenant_id + broker_account_id
```

---

## 49. Order State Machine

```text
NEW
 ↓
SUBMITTED
 ↓
ACKNOWLEDGED
 ↓
PARTIALLY_FILLED
 ↓
FILLED
```

Other states:

```text
REJECTED
CANCELLED
EXPIRED
UNKNOWN
```

UNKNOWN requires reconciliation before resubmission.

---

## 50. Broker Adapter

Broker abstraction:

```python
class Broker:
    place_order()
    modify_order()
    cancel_order()
    get_orders()
    get_positions()
    get_holdings()
    get_margin()
    subscribe_market_data()
```

Initial adapter:

```text
ZerodhaBroker
```

Future adapters may support additional Indian brokers.

---

## 51. Reconciliation Engine

Reconciliation is scoped by:

```text
tenant_id
broker_account_id
```

Compare:

- Internal orders
- Broker orders
- Trades
- Positions
- Holdings
- Margin

A mismatch should halt the affected broker account and trigger reconciliation.

---

## 52. Event-Driven Architecture

Every material event must carry tenant context.

Examples:

```text
SIGNAL_GENERATED
STRATEGY_SELECTED
TARGET_POSITION_CHANGED
RISK_APPROVED
RISK_REJECTED
ORDER_SUBMITTED
ORDER_FILLED
POSITION_CHANGED
TRADING_HALTED
```

Envelope:

```json
{
  "event_id": "...",
  "tenant_id": "...",
  "portfolio_id": "...",
  "timestamp": "...",
  "event_type": "...",
  "payload": {}
}
```

---

## 53. Event Storage

Tenant events must support:

- Audit
- Replay
- Debugging
- Compliance
- Model evaluation

Tenant A must never retrieve Tenant B event streams.

---

## 54. Event Replay

Replay operates inside an explicit tenant sandbox.

```text
Historical Events
      ↓
Tenant Replay Session
      ↓
Strategy
      ↓
AI Selector
      ↓
Portfolio
      ↓
Risk
      ↓
Execution Simulator
```

Replay must never connect to live execution.

---

## 55. PostgreSQL Design

Initial recommendation: use a shared PostgreSQL cluster with strict logical tenancy.

All tenant tables contain `tenant_id`.

PostgreSQL Row Level Security should be considered for defense in depth.

Application queries must always be tenant scoped.

---

## 56. Tenant Database Security

Defense layers:

```text
Authentication
      ↓
Tenant Context Resolution
      ↓
Application Authorization
      ↓
Repository Tenant Filter
      ↓
PostgreSQL Row-Level Security
```

Never rely on a single application-layer filter.

---

## 57. Large Tenant Scaling

Future deployment options may include:

```text
shared DB/shared schema
shared DB/separate schema
dedicated database
dedicated cluster
```

The domain model should allow future tenant migration without changing business semantics.

---

## 58. Object Storage

Object storage may contain:

- Historical datasets
- Backtest artifacts
- ML models
- Strategy artifacts
- Reports

Path structure:

```text
/tenants/{tenant_id}/...
```

Tenant-scoped authorization is mandatory.

---

## 59. Redis

Redis may be used for:

- Caching
- Locks
- Queues
- Temporary strategy state

Redis keys must be tenant namespaced.

Example:

```text
tenant:{tenant_id}:portfolio:{portfolio_id}:...
```

Redis must not be the authoritative financial ledger.

---

## 60. Docker Compose Architecture

The platform runs as a set of Docker Compose services grouped by domain:

```text
api-gateway
market-data
strategy-engine
intelligence
portfolio-manager
risk-manager
execution-engine
postgres
redis
minio (object storage)
reverse-proxy (Traefik or Nginx)
```

Each service runs as one or more containers managed by a single `docker-compose.yml`.

Tenant isolation happens at the application and data layer, not the container layer.

For development and MVP, all services run on a single Docker host. Future scaling may introduce Docker Swarm or a Kubernetes migration when multi-node high availability is required.

---

## 61. Dedicated Tenant Runtime

The platform should support future dedicated tenancy for high-value tenants.

Dedicated tenant services may run as separate Compose profiles or override files:

```text
docker-compose.yml                  (shared platform)
docker-compose.tenant-123.yml      (dedicated overrides)
```

This can support:

- Stronger isolation via separate containers
- Custom resource limits
- Regulatory requirements
- Enterprise contracts

A future Kubernetes migration may deploy dedicated tenant workloads as separate namespaces.

---

## 62. Resource Isolation

Every tenant workload must support quotas.

Examples:

```text
CPU
memory
concurrent backtests
strategy instances
AI inference requests
storage
market subscriptions
```

Use Docker Compose resource limits (`deploy.resources.limits` for CPU and memory) and application-level queue quotas to prevent noisy-neighbor problems.

Backtest and strategy concurrency limits are enforced at the application layer, not the container layer.

---

## 63. Network Isolation

Docker Compose networks should ensure that strategy containers cannot directly reach broker APIs.

```text
internal-network:    api-gateway, strategy-engine, intelligence,
                     portfolio-manager, risk-manager, postgres, redis

execution-network:   execution-engine, risk-manager, postgres

external-network:    execution-engine, market-data, reverse-proxy
```

Strategies should communicate only with approved internal services.

Only the execution-engine and market-data services should have network access to external endpoints (broker APIs, market feeds).

The reverse-proxy exposes only the API gateway to the host.

---

## 64. Secret Management

Secrets must be tenant scoped.

Examples:

```text
Zerodha API key
access token
refresh/session information
tenant API credentials
```

Secrets should be encrypted at rest in PostgreSQL (application-level encryption).

For MVP, secrets are managed via environment variables (`.env` files excluded from version control) and Docker Compose secrets.

Future versions should consider:

- HashiCorp Vault
- Cloud KMS

---

## 65. Tenant API Authentication

External API requests must authenticate:

```text
user
tenant
permissions
```

Never accept a client-provided `tenant_id` as authoritative without validating membership.

Tenant context should originate from authenticated identity.

---

## 66. API Authorization

Every sensitive object lookup must effectively check:

```text
requested_resource.tenant_id == authenticated_tenant_id
```

Object IDs alone must never grant access.

---

## 67. Strategy Health

Health is calculated separately for every tenant strategy instance.

Example:

```text
Tenant A
Momentum health = 0.88

Tenant B
Momentum health = 0.41
```

Even if both use the same underlying strategy code.

---

## 68. Capital Allocation

Each tenant's AI allocates only that tenant's capital.

Example:

```text
Tenant A
₹10 lakh

Momentum       ₹3 lakh
Breakout       ₹2 lakh
Stat Arb       ₹2 lakh
Cash           ₹3 lakh
```

Tenant B may have completely different allocations.

---

## 69. Cash as a Strategy

Cash is always a valid allocation.

AI must be permitted to return:

```text
100% CASH
```

The system must never force trading merely because capital is available.

---

## 70. Decision Logging

Every AI decision stores:

```text
tenant_id
portfolio_id
decision_id
timestamp
market regime
strategy candidates
strategy metrics
selected weights
confidence
portfolio context
risk context
```

Outcomes later include:

```text
return
drawdown
MFE
MAE
cost
slippage
risk-adjusted reward
```

---

## 71. Explainability

A tenant should be able to ask:

> Why did my system buy INFY?

The platform should reconstruct the market regime, candidate strategy signals, AI allocation, portfolio target, risk decision, and actual execution.

---

## 72. Audit Logging

Security-sensitive actions must be immutable and auditable.

Examples:

```text
user login
broker connected
risk policy changed
strategy enabled
strategy promoted to live
trading halted
manual order intervention
credential rotated
tenant suspended
```

Audit records include:

```text
tenant_id
user_id
timestamp
action
resource
before
after
IP/device metadata where appropriate
```

---

## 73. Observability

Platform-level dashboards:

- Cluster health
- Database health
- Broker API health
- Market-data health
- Queue health

Tenant dashboards:

- Portfolio equity
- Daily P&L
- Positions
- Drawdown
- Strategies
- AI allocations
- Risk utilization
- Execution quality

Tenant dashboards must never expose another tenant's metrics.

---

## 74. Alerts

Tenant-specific alerts:

- Strategy disabled
- Risk threshold reached
- Trading halted
- Position mismatch
- Excessive slippage
- Broker session expired

Platform alerts:

- Zerodha outage
- Market feed failure
- DB failure
- Cluster degradation
- Execution-service incident

---

## 75. Tenant Onboarding

```text
Create tenant
      ↓
Create admin
      ↓
Select subscription/tier
      ↓
Create portfolio
      ↓
Configure risk policy
      ↓
Connect broker
      ↓
Select strategies
      ↓
Run backtests
      ↓
Paper trade
      ↓
Shadow trade
      ↓
Enable low-capital live trading
```

Live execution must not be enabled immediately after broker connection.

---

## 76. Trading Environment Separation

The platform must distinguish:

```text
BACKTEST
PAPER
SHADOW
LIVE
```

A portfolio's environment must be explicit.

Live broker credentials must never be loaded into backtest jobs.

---

## 77. Manual Kill Switch

Every tenant must have an immediate:

```text
HALT TRADING
```

control.

Scope options:

```text
Strategy
Portfolio
Broker Account
Entire Tenant
```

Platform operators must also have a global emergency halt mechanism.

---

## 78. Billing and Usage

Multi-tenancy should support future metering.

Possible usage dimensions:

```text
active strategies
backtest compute
historical data storage
AI inference
live broker accounts
market subscriptions
retained event history
```

Billing is not required for the first internal MVP but the usage model should be instrumented.

---

## 79. Subscription Tiers

Future example:

```text
Research
Trader
Pro
Enterprise
```

Capabilities may differ in:

- Number of strategies
- Number of portfolios
- Backtest concurrency
- Data retention
- AI features
- Dedicated execution
- Dedicated infrastructure

---

## 80. Rate Limiting

Apply rate limits at:

```text
platform
tenant
user
broker account
```

Broker API limits must be enforced independently per appropriate broker/account constraints.

No tenant may consume the entire broker integration capacity.

---

## 81. Strategy Development Workflow

```text
Develop
   ↓
Unit Test
   ↓
Historical Backtest
   ↓
Walk-Forward
   ↓
Stress Test
   ↓
Paper Trade
   ↓
Shadow Trade
   ↓
Low-Capital Live
   ↓
Review
   ↓
Production Allocation
```

---

## 82. Strategy Versioning

Strategy code is immutable after release.

Example:

```text
momentum-v1.0
momentum-v1.1
momentum-v2.0
```

Tenant configuration versions are independently immutable.

Therefore a live instance is identified by:

```text
strategy_code_version + strategy_config_version
```

---

## 83. Promotion Gates

Tenants may configure minimum gates such as:

```text
minimum backtest duration
minimum trade count
maximum drawdown
minimum Sharpe
out-of-sample pass
minimum paper-trading duration
minimum shadow-trading duration
```

Live promotion requires all mandatory gates to pass.

---

## 84. MVP Phase 1 — Platform Foundation

Build:

- Docker Compose stack (single host)
- PostgreSQL
- Redis
- Object storage
- Authentication
- Tenant model
- User/RBAC model
- Portfolio model
- Tenant-scoped APIs
- Basic audit system

No broker trading.

---

## 85. MVP Phase 2 — Quant Research

Build:

- Historical data ingestion
- Common Strategy API
- Momentum strategy
- Mean-reversion strategy
- Backtest engine
- Multi-tenant backtest scheduler
- Standard metrics
- Experiment tracking

---

## 86. MVP Phase 3 — Live Data and Paper Trading

Build:

- Zerodha live market gateway
- Paper Broker
- Portfolio Manager
- Tenant Risk Manager
- Real-time signals
- Paper trading
- Tenant dashboards

---

## 87. MVP Phase 4 — Execution

Build:

- Tenant broker-account management
- Credential vault
- Zerodha order adapter
- Execution state machine
- Per-account leader election
- Reconciliation
- Kill switch
- Low-capital live mode

---

## 88. MVP Phase 5 — AI Strategy Selection

Build:

- Market regime model
- Strategy health scoring
- Contextual bandit
- AI capital allocation
- Cash allocation
- Shadow evaluation
- Decision explainability

---

## 89. MVP Phase 6 — Advanced AI

Add:

- LLM supervisor
- Market news context
- Counterfactual evaluation
- Adaptive strategy allocation
- Automated strategy degradation detection

---

## 90. Success Criteria

The platform succeeds when it can prove:

1. Multiple tenants can operate concurrently.
2. Tenant orders, portfolios, data, credentials, and risk policies remain isolated.
3. The same strategy code works in backtest, paper, shadow, and live modes.
4. Every live order maps to Tenant → Portfolio → Strategy Signal → AI Decision → Portfolio Decision → Risk Approval.
5. AI cannot directly place broker orders.
6. Risk Manager can independently reject any trade.
7. A failure affecting one tenant does not unnecessarily halt others.
8. Broker reconciliation is independent per tenant/account.
9. Backtest compute is fairly scheduled across tenants.
10. Every decision is auditable and replayable.

---

## 91. Core Multi-Tenant Safety Invariants

The following must never be violated:

```text
Every financial object belongs to exactly one tenant.
Every trade belongs to exactly one portfolio.
Every broker account belongs to exactly one tenant.
Every live execution resolves an authenticated tenant context.
Strategies cannot access broker credentials.
AI cannot access broker credentials.
AI cannot directly place orders.
AI cannot override Risk Manager.
Risk Manager fails closed.
One tenant cannot change another tenant's strategy.
One tenant cannot consume another tenant's capital.
Signals are never netted across tenants.
Orders are never netted across tenants.
Positions are never reconciled across tenants.
Tenant secrets remain isolated.
Tenant proprietary data is never used for another tenant's AI training without explicit authorization.
Unknown tenant context means no trade.
Unknown broker state means no trade.
Cash is always a valid strategy.
```

---

## 92. Long-Term Architecture

The intended evolution is:

```text
                       Shared Market Infrastructure
                                  │
                                  ▼
                     Multi-Tenant Trading Platform
                                  │
       ┌──────────────────────────┼──────────────────────────┐
       ▼                          ▼                          ▼
    Tenant A                   Tenant B                   Tenant C
       │                          │                          │
       ▼                          ▼                          ▼
 Multiple Strategies        Multiple Strategies        Multiple Strategies
       │                          │                          │
       ▼                          ▼                          ▼
 AI Allocation              AI Allocation              AI Allocation
       │                          │                          │
       ▼                          ▼                          ▼
 Portfolio Manager          Portfolio Manager          Portfolio Manager
       │                          │                          │
       ▼                          ▼                          ▼
 Risk Manager               Risk Manager               Risk Manager
       │                          │                          │
       ▼                          ▼                          ▼
 Broker Executor            Broker Executor            Broker Executor
       │                          │                          │
       ▼                          ▼                          ▼
 Broker Account A           Broker Account B           Broker Account C
```

The platform may eventually support:

- Thousands of tenants
- Multiple broker integrations
- Multiple portfolios per tenant
- Tenant-specific strategies
- Shared strategy marketplace
- Dedicated enterprise runtimes
- Portfolio optimization
- Options risk
- Cross-asset strategies
- Privacy-preserving aggregate learning

---

## 93. Product Vision

Aegis Trader should not become a collection of independent trading bots.

It should become a **multi-tenant quantitative trading operating system** where:

> Strategies generate opinions.
>
> AI decides which strategies deserve capital.
>
> The Portfolio Manager translates those opinions into tenant-specific target exposures.
>
> The Risk Manager determines what is permissible.
>
> The Execution Engine safely interacts with each tenant's broker account.
>
> Tenant isolation ensures that no strategy, credential, position, risk decision, or execution can cross organizational boundaries.
>
> Every trading decision remains reproducible, explainable, auditable, and backtestable.
