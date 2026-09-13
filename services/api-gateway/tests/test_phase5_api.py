"""Phase 5 API tests: market regimes, strategy health, AI allocation, shadow results."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.models import (
    BacktestRun,
    OHLCVBar,
    Strategy,
    StrategyConfig,
)
from tests.conftest import (
    auth_header,
    create_test_portfolio,
    create_test_tenant,
    create_test_user,
)


def _seed_ohlcv(db, tenant, symbol="RELIANCE", exchange="NSE", timeframe="1d", bars=20):
    """Seed OHLCV bars for regime computation."""
    import random

    base_price = 2500.0
    for i in range(bars):
        price = base_price + random.uniform(-50, 50)
        bar = OHLCVBar(
            tenant_id=tenant.id,
            symbol=symbol,
            exchange=exchange,
            timeframe=timeframe,
            timestamp=datetime(2024, 1, 1 + i, tzinfo=timezone.utc),
            open=price,
            high=price + random.uniform(0, 30),
            low=price - random.uniform(0, 30),
            close=price + random.uniform(-20, 20),
            volume=random.uniform(100000, 500000),
        )
        db.add(bar)
    db.flush()


def _seed_strategy_with_backtests(db, tenant, portfolio):
    """Create a strategy, config, and completed backtests for health evaluation."""
    strategy = Strategy(
        tenant_id=tenant.id,
        name=f"test-momentum-{uuid.uuid4().hex[:8]}",
        version="1.0",
        strategy_type="MOMENTUM",
    )
    db.add(strategy)
    db.flush()

    config = StrategyConfig(
        tenant_id=tenant.id,
        strategy_id=strategy.id,
        portfolio_id=portfolio.id,
        parameters={"lookback": 20},
        lifecycle_status="PAPER_TRADING",
    )
    db.add(config)
    db.flush()

    # Add completed backtests with metrics
    for i in range(3):
        bt = BacktestRun(
            tenant_id=tenant.id,
            portfolio_id=portfolio.id,
            strategy_config_id=config.id,
            symbol="RELIANCE",
            exchange="NSE",
            timeframe="1d",
            status="COMPLETED",
            start_date=datetime(2024, 1, 1, tzinfo=timezone.utc),
            end_date=datetime(2024, 3, 31, tzinfo=timezone.utc),
            metrics={
                "net_return": 5.0 + i,
                "sharpe": 1.5 + i * 0.1,
                "max_drawdown": 3.0 + i * 0.5,
                "total_trades": 10 + i,
                "win_rate": 0.75,
            },
        )
        db.add(bt)
    db.flush()
    return strategy, config


# --- Market Regime tests ---


def test_compute_regime_insufficient_data(client, db):
    """Compute regime with no OHLCV data returns INSUFFICIENT_DATA."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    resp = client.post(
        "/api/market-regimes/compute",
        json={"symbol": "RELIANCE", "exchange": "NSE", "timeframe": "1d"},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["regime_label"] == "INSUFFICIENT_DATA"
    assert data["confidence"] == 0.0


def test_compute_regime_with_data(client, db):
    """Compute regime with seeded OHLCV data returns a valid regime."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    _seed_ohlcv(db, tenant, bars=20)

    resp = client.post(
        "/api/market-regimes/compute",
        json={
            "symbol": "RELIANCE",
            "exchange": "NSE",
            "timeframe": "1d",
            "lookback_bars": 20,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["regime_label"] in [
        "HIGH_VOLATILITY_TRENDING",
        "HIGH_VOLATILITY_MEAN_REVERTING",
        "LOW_VOLATILITY_TRENDING",
        "LOW_VOLATILITY_RANGE_BOUND",
    ]
    assert 0.0 <= data["confidence"] <= 1.0
    assert data["symbol"] == "RELIANCE"
    assert data["features"] is not None


def test_list_regimes(client, db):
    """List market regimes."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    _seed_ohlcv(db, tenant, bars=15)

    # Compute a regime first
    client.post(
        "/api/market-regimes/compute",
        json={"symbol": "RELIANCE"},
        headers=auth_header(token),
    )

    resp = client.get("/api/market-regimes", headers=auth_header(token))
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1


def test_get_regime_by_id(client, db):
    """Get a specific regime by ID."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    _seed_ohlcv(db, tenant, bars=15)

    create_resp = client.post(
        "/api/market-regimes/compute",
        json={"symbol": "RELIANCE"},
        headers=auth_header(token),
    )
    regime_id = create_resp.json()["id"]

    resp = client.get(f"/api/market-regimes/{regime_id}", headers=auth_header(token))
    assert resp.status_code == 200
    assert resp.json()["id"] == regime_id


def test_get_regime_not_found(client, db):
    """Get non-existent regime returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    resp = client.get(f"/api/market-regimes/{uuid.uuid4()}", headers=auth_header(token))
    assert resp.status_code == 404


# --- Strategy Health tests ---


def test_evaluate_health_no_data(client, db):
    """Evaluate health with no backtests returns NO_DATA or UNKNOWN."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)

    strategy = Strategy(
        tenant_id=tenant.id,
        name="empty-strat",
        version="1.0",
        strategy_type="MOMENTUM",
    )
    db.add(strategy)
    db.flush()
    config = StrategyConfig(
        tenant_id=tenant.id,
        strategy_id=strategy.id,
        portfolio_id=portfolio.id,
        parameters={},
    )
    db.add(config)
    db.flush()

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/evaluate",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["health_status"] in ["NO_DATA", "UNKNOWN", "FAILING"]
    assert data["total_trades"] == 0


def test_evaluate_health_with_backtests(client, db):
    """Evaluate health with completed backtests returns meaningful scores."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/evaluate",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["health_score"] > 0
    assert data["total_trades"] > 0
    assert data["win_rate"] > 0


def test_list_health_scores(client, db):
    """List health scores for a tenant."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Evaluate first
    client.post(
        f"/api/tenants/{tenant.id}/strategy-health/evaluate",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )

    resp = client.get(
        f"/api/tenants/{tenant.id}/strategy-health",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_health_tenant_isolation(client, db):
    """Health scores from tenant A not visible to tenant B."""
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user_a, token_a = create_test_user(db, tenant_a, role="RESEARCHER")
    _user_b, token_b = create_test_user(db, tenant_b, role="RESEARCHER")
    portfolio_a = create_test_portfolio(db, tenant_a)
    _strategy, config = _seed_strategy_with_backtests(db, tenant_a, portfolio_a)

    client.post(
        f"/api/tenants/{tenant_a.id}/strategy-health/evaluate",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio_a.id),
        },
        headers=auth_header(token_a),
    )

    # Tenant B should not see tenant A health scores
    resp = client.get(
        f"/api/tenants/{tenant_a.id}/strategy-health",
        headers=auth_header(token_b),
    )
    assert resp.status_code == 403


# --- AI Allocation tests ---


def test_allocate_no_strategies(client, db):
    """Allocate with no strategy configs returns 100% cash."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    portfolio.trading_mode = "PAPER"
    db.flush()

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "LIVE"},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["cash_weight"] == 1.0
    assert data["strategy_weights"] == {}


def test_allocate_with_strategies(client, db):
    """Allocate with strategy configs returns weights that sum to ~1.0."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    portfolio.trading_mode = "PAPER"
    db.flush()
    _seed_ohlcv(db, tenant, bars=20)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "LIVE"},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    total = sum(data["strategy_weights"].values()) + data["cash_weight"]
    assert abs(total - 1.0) < 0.01
    assert data["explanation"] is not None
    assert data["mode"] == "LIVE"


def test_allocate_shadow_mode(client, db):
    """Allocate in SHADOW mode records the decision."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _seed_ohlcv(db, tenant, bars=15)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["mode"] == "SHADOW"
    assert "SHADOW" in data["explanation"]


def test_list_decisions(client, db):
    """List AI decisions for a tenant."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)

    client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )

    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/decisions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_get_decision_by_id(client, db):
    """Get a specific AI decision by ID."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)

    create_resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )
    decision_id = create_resp.json()["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/decisions/{decision_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == decision_id


def test_decision_not_found(client, db):
    """Get non-existent decision returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/decisions/{uuid.uuid4()}",
        headers=auth_header(token),
    )
    assert resp.status_code == 404


# --- Shadow Result tests ---


def test_create_shadow_result(client, db):
    """Create a shadow result for an AI decision."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Create an AI decision first
    decision_resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )
    decision_id = decision_resp.json()["id"]

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/shadow-results",
        json={
            "ai_decision_id": decision_id,
            "strategy_config_id": str(config.id),
            "hypothetical_return": 0.05,
            "actual_return": 0.03,
            "evaluation_start": "2024-01-01T00:00:00Z",
            "evaluation_end": "2024-03-31T00:00:00Z",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["ai_decision_id"] == decision_id
    assert abs(data["hypothetical_return"] - 0.05) < 0.001
    assert abs(data["actual_return"] - 0.03) < 0.001


def test_list_shadow_results(client, db):
    """List shadow results for a tenant."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    decision_resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )
    decision_id = decision_resp.json()["id"]

    client.post(
        f"/api/tenants/{tenant.id}/ai/shadow-results",
        json={
            "ai_decision_id": decision_id,
            "strategy_config_id": str(config.id),
            "hypothetical_return": 0.02,
            "actual_return": 0.01,
            "evaluation_start": "2024-01-01T00:00:00Z",
            "evaluation_end": "2024-01-31T00:00:00Z",
        },
        headers=auth_header(token),
    )

    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/shadow-results",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_shadow_result_invalid_decision(client, db):
    """Creating shadow result with non-existent decision returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/shadow-results",
        json={
            "ai_decision_id": str(uuid.uuid4()),
            "strategy_config_id": str(config.id),
            "hypothetical_return": 0.05,
            "actual_return": 0.03,
            "evaluation_start": "2024-01-01T00:00:00Z",
            "evaluation_end": "2024-03-31T00:00:00Z",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 404


def test_ai_tenant_isolation(client, db):
    """AI decisions from tenant A not accessible by tenant B."""
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user_a, token_a = create_test_user(db, tenant_a, role="TENANT_ADMIN")
    _user_b, token_b = create_test_user(db, tenant_b, role="TENANT_ADMIN")
    portfolio_a = create_test_portfolio(db, tenant_a)

    client.post(
        f"/api/tenants/{tenant_a.id}/ai/allocate",
        json={"portfolio_id": str(portfolio_a.id)},
        headers=auth_header(token_a),
    )

    resp = client.get(
        f"/api/tenants/{tenant_a.id}/ai/decisions",
        headers=auth_header(token_b),
    )
    assert resp.status_code == 403
