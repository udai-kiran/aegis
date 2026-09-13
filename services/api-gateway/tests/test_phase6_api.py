"""Phase 6 API tests: LLM supervisor, news, counterfactual, reward, degradation."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.models import (
    BacktestRun,
    OHLCVBar,
    Strategy,
    StrategyConfig,
    StrategyHealthScore,
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
    """Create a strategy, config, and completed backtests."""
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


def _seed_health_scores(db, tenant, config, portfolio, scores):
    """Seed health score records for degradation testing."""
    for i, score_val in enumerate(scores):
        health = StrategyHealthScore(
            tenant_id=tenant.id,
            strategy_config_id=config.id,
            portfolio_id=portfolio.id,
            win_rate=0.5,
            avg_return=0.01,
            sharpe_ratio=0.3,
            max_drawdown=5.0,
            total_trades=10,
            recent_pnl=0.01,
            health_score=score_val,
            health_status="HEALTHY"
            if score_val >= 60
            else ("DEGRADED" if score_val >= 30 else "FAILING"),
            evaluated_at=datetime(2024, 1, 1 + i, tzinfo=timezone.utc),
        )
        db.add(health)
    db.flush()


# --- News tests ---


def test_create_news_item(client, db):
    """Create a news item with sentiment."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    resp = client.post(
        f"/api/tenants/{tenant.id}/news",
        json={
            "headline": "RBI holds interest rates steady",
            "source": "Reuters",
            "symbols": ["NIFTY", "BANKNIFTY"],
            "sentiment_score": 0.3,
            "sentiment_label": "POSITIVE",
            "published_at": "2024-06-15T10:00:00Z",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["headline"] == "RBI holds interest rates steady"
    assert data["sentiment_label"] == "POSITIVE"
    assert abs(data["sentiment_score"] - 0.3) < 0.001
    assert data["tenant_id"] == str(tenant.id)


def test_list_news(client, db):
    """List news items for a tenant."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    client.post(
        f"/api/tenants/{tenant.id}/news",
        json={
            "headline": "Markets rally on earnings",
            "sentiment_score": 0.7,
            "sentiment_label": "POSITIVE",
            "published_at": "2024-06-15T10:00:00Z",
        },
        headers=auth_header(token),
    )

    resp = client.get(f"/api/tenants/{tenant.id}/news", headers=auth_header(token))
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_get_news_by_id(client, db):
    """Get a single news item by ID."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    create_resp = client.post(
        f"/api/tenants/{tenant.id}/news",
        json={
            "headline": "Test headline",
            "sentiment_score": -0.5,
            "sentiment_label": "NEGATIVE",
            "published_at": "2024-06-15T10:00:00Z",
        },
        headers=auth_header(token),
    )
    news_id = create_resp.json()["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/news/{news_id}", headers=auth_header(token)
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == news_id


def test_news_not_found(client, db):
    """Get non-existent news item returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")

    resp = client.get(
        f"/api/tenants/{tenant.id}/news/{uuid.uuid4()}", headers=auth_header(token)
    )
    assert resp.status_code == 404


def test_news_tenant_isolation(client, db):
    """News from tenant A not accessible by tenant B."""
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user_a, token_a = create_test_user(db, tenant_a, role="RESEARCHER")
    _user_b, token_b = create_test_user(db, tenant_b, role="RESEARCHER")

    client.post(
        f"/api/tenants/{tenant_a.id}/news",
        json={
            "headline": "Tenant A news",
            "sentiment_score": 0.1,
            "sentiment_label": "NEUTRAL",
            "published_at": "2024-06-15T10:00:00Z",
        },
        headers=auth_header(token_a),
    )

    resp = client.get(f"/api/tenants/{tenant_a.id}/news", headers=auth_header(token_b))
    assert resp.status_code == 403


# --- Supervisor tests ---


def test_supervisor_recommend_no_strategies(client, db):
    """Supervisor with no strategies returns empty list."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/supervisor/recommend",
        json={"portfolio_id": str(portfolio.id)},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json() == []


def test_supervisor_recommend_with_health(client, db):
    """Supervisor with degraded strategy health generates recommendations."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Seed a DEGRADED health score
    _seed_health_scores(db, tenant, config, portfolio, [35.0])

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/supervisor/recommend",
        json={"portfolio_id": str(portfolio.id)},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert len(data) >= 1
    action_types = [a["action_type"] for a in data]
    assert "WEIGHT_CHANGE" in action_types or "CASH_ALLOCATION" in action_types


def test_supervisor_list_actions(client, db):
    """List supervisor actions for a tenant."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)
    _seed_health_scores(db, tenant, config, portfolio, [35.0])

    client.post(
        f"/api/tenants/{tenant.id}/ai/supervisor/recommend",
        json={"portfolio_id": str(portfolio.id)},
        headers=auth_header(token),
    )

    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/supervisor/actions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_supervisor_get_action(client, db):
    """Get a single supervisor action by ID."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)
    _seed_health_scores(db, tenant, config, portfolio, [35.0])

    rec_resp = client.post(
        f"/api/tenants/{tenant.id}/ai/supervisor/recommend",
        json={"portfolio_id": str(portfolio.id)},
        headers=auth_header(token),
    )
    actions = rec_resp.json()
    assert len(actions) >= 1
    action_id = actions[0]["id"]
    resp = client.get(
        f"/api/tenants/{tenant.id}/ai/supervisor/actions/{action_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == action_id


def test_supervisor_tenant_isolation(client, db):
    """Supervisor actions from tenant A not accessible by tenant B."""
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user_a, token_a = create_test_user(db, tenant_a, role="TENANT_ADMIN")
    _user_b, token_b = create_test_user(db, tenant_b, role="TENANT_ADMIN")

    resp = client.get(
        f"/api/tenants/{tenant_a.id}/ai/supervisor/actions",
        headers=auth_header(token_b),
    )
    assert resp.status_code == 403


# --- Reward tests ---


def test_record_reward(client, db):
    """Record a reward and check arm state updates."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/reward",
        json={
            "portfolio_id": str(portfolio.id),
            "arm_name": "MOMENTUM",
            "reward": 0.8,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["arm_name"] == "MOMENTUM"
    assert data["alpha"] > 1.0  # Started at 1.0, added reward
    assert data["total_pulls"] == 1


def test_record_reward_multiple(client, db):
    """Multiple rewards accumulate."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)

    for _ in range(3):
        client.post(
            f"/api/tenants/{tenant.id}/ai/reward",
            json={
                "portfolio_id": str(portfolio.id),
                "arm_name": "MEAN_REVERSION",
                "reward": 0.5,
            },
            headers=auth_header(token),
        )

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/reward",
        json={
            "portfolio_id": str(portfolio.id),
            "arm_name": "MEAN_REVERSION",
            "reward": 0.5,
        },
        headers=auth_header(token),
    )
    data = resp.json()
    assert data["total_pulls"] == 4
    assert data["alpha"] > 1.0


def test_record_reward_portfolio_not_found(client, db):
    """Reward for non-existent portfolio returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/reward",
        json={
            "portfolio_id": str(uuid.uuid4()),
            "arm_name": "MOMENTUM",
            "reward": 0.5,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 404


# --- Counterfactual tests ---


def test_counterfactual_evaluate(client, db):
    """Counterfactual evaluation returns comparison data."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = create_test_portfolio(db, tenant)
    _seed_ohlcv(db, tenant, bars=20)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Create an AI decision first
    decision_resp = client.post(
        f"/api/tenants/{tenant.id}/ai/allocate",
        json={"portfolio_id": str(portfolio.id), "mode": "SHADOW"},
        headers=auth_header(token),
    )
    assert decision_resp.status_code == 201
    decision_id = decision_resp.json()["id"]

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/counterfactual/evaluate",
        json={
            "ai_decision_id": decision_id,
            "evaluation_start": "2024-01-01T00:00:00Z",
            "evaluation_end": "2024-03-31T00:00:00Z",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["ai_decision_id"] == decision_id
    assert "comparisons" in data
    assert "regret" in data
    assert "actual_weighted_return" in data
    assert len(data["comparisons"]) >= 1
    assert isinstance(data["regret"], (int, float))
    assert data["regret"] >= 0
    assert isinstance(data["actual_weighted_return"], (int, float))


def test_counterfactual_decision_not_found(client, db):
    """Counterfactual for non-existent decision returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.post(
        f"/api/tenants/{tenant.id}/ai/counterfactual/evaluate",
        json={
            "ai_decision_id": str(uuid.uuid4()),
            "evaluation_start": "2024-01-01T00:00:00Z",
            "evaluation_end": "2024-03-31T00:00:00Z",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 404


# --- Degradation tests ---


def test_degradation_no_health_data(client, db):
    """Degradation check with no health data shows no degradation."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/degradation-check",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["is_degrading"] is False
    assert data["alerts"] == []


def test_degradation_with_declining_scores(client, db):
    """Degradation check with declining health scores detects degradation."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Seed declining health scores (newest first when queried)
    declining_scores = [80.0, 70.0, 55.0, 40.0, 25.0, 15.0, 10.0]
    _seed_health_scores(db, tenant, config, portfolio, declining_scores)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/degradation-check",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    data = resp.json()
    # Should detect some form of degradation (sharpe or score decline)
    assert len(data["health_trend"]) > 0
    assert data["is_degrading"] is True
    assert len(data["alerts"]) >= 1
    alert_types = {a["alert_type"] for a in data["alerts"]}
    assert {"SCORE_DECLINE", "SHARPE_BELOW_THRESHOLD"} & alert_types


def test_degradation_auto_demote(client, db):
    """Degradation check with auto_demote updates lifecycle status."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)
    _strategy, config = _seed_strategy_with_backtests(db, tenant, portfolio)

    # Seed health scores with low sharpe (below 0.5 threshold)
    health = StrategyHealthScore(
        tenant_id=tenant.id,
        strategy_config_id=config.id,
        portfolio_id=portfolio.id,
        win_rate=0.3,
        avg_return=-0.02,
        sharpe_ratio=0.1,
        max_drawdown=20.0,
        total_trades=10,
        recent_pnl=-0.05,
        health_score=15.0,
        health_status="FAILING",
        evaluated_at=datetime(2024, 6, 1, tzinfo=timezone.utc),
    )
    db.add(health)
    db.flush()

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/degradation-check",
        json={
            "strategy_config_id": str(config.id),
            "portfolio_id": str(portfolio.id),
            "auto_demote": True,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["is_degrading"] is True
    assert len(data["alerts"]) > 0

    # Verify lifecycle was actually changed
    db.expire_all()
    from app.models import StrategyConfig as SC

    updated_config = db.query(SC).filter(SC.id == config.id).first()
    assert updated_config.lifecycle_status == "REDUCED_CAPITAL"


def test_degradation_config_not_found(client, db):
    """Degradation check for non-existent config returns 404."""
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RESEARCHER")
    portfolio = create_test_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-health/degradation-check",
        json={
            "strategy_config_id": str(uuid.uuid4()),
            "portfolio_id": str(portfolio.id),
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 404
