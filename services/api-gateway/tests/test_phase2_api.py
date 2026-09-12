"""Phase 2 API tests: OHLCV, strategies, strategy configs, backtests, metrics."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pandas as pd
from unittest.mock import patch

from app.backtest.metrics import calculate_metrics
from app.models import Strategy, StrategyConfig
from tests.conftest import (
    auth_header,
    create_test_portfolio,
    create_test_tenant,
    create_test_user,
)

BASE_TS = datetime(2024, 1, 1, tzinfo=timezone.utc)


def _ohlcv_bars(n: int, symbol: str = "RELIANCE") -> list[dict]:
    """Build ``n`` OHLCV bar payloads with ISO-formatted timestamps."""
    bars = []
    for i in range(n):
        ts = BASE_TS + timedelta(days=i)
        bars.append(
            {
                "symbol": symbol,
                "exchange": "NSE",
                "timeframe": "1d",
                "timestamp": ts.isoformat(),
                "open": 100.0 + i,
                "high": 102.0 + i,
                "low": 98.0 + i,
                "close": 101.0 + i,
                "volume": 1000.0,
            }
        )
    return bars


def _make_strategy(db, tenant, name="momentum-strat", version="1.0") -> Strategy:
    strategy = Strategy(
        tenant_id=tenant.id,
        name=name,
        version=version,
        strategy_type="momentum",
    )
    db.add(strategy)
    db.flush()
    return strategy


def _make_config(db, tenant, strategy, portfolio) -> StrategyConfig:
    config = StrategyConfig(
        tenant_id=tenant.id,
        strategy_id=strategy.id,
        portfolio_id=portfolio.id,
        parameters={"lookback": 2},
    )
    db.add(config)
    db.flush()
    return config


# --- OHLCV tests -------------------------------------------------------------


def test_ohlcv_upload_and_query(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    create_test_portfolio(db, tenant)

    bars = _ohlcv_bars(5)
    resp = client.post(
        f"/api/tenants/{tenant.id}/ohlcv",
        json={"bars": bars},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["count"] == 5

    resp = client.get(
        f"/api/tenants/{tenant.id}/ohlcv",
        params={"symbol": "RELIANCE"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 5


def test_ohlcv_upload_requires_auth(client, db):
    tenant = create_test_tenant(db)
    resp = client.post(
        f"/api/tenants/{tenant.id}/ohlcv",
        json={"bars": _ohlcv_bars(1)},
    )
    assert resp.status_code == 403


def test_ohlcv_cross_tenant_denied(client, db):
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user, token = create_test_user(db, tenant_a)

    resp = client.post(
        f"/api/tenants/{tenant_b.id}/ohlcv",
        json={"bars": _ohlcv_bars(1)},
        headers=auth_header(token),
    )
    assert resp.status_code == 403


# --- Strategy tests ------------------------------------------------------------


def test_strategy_crud(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategies",
        json={"name": "test-momentum", "strategy_type": "momentum"},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    strategy_id = resp.json()["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/strategies/{strategy_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "test-momentum"

    resp = client.patch(
        f"/api/tenants/{tenant.id}/strategies/{strategy_id}",
        json={"description": "updated description"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["description"] == "updated description"

    resp = client.get(
        f"/api/tenants/{tenant.id}/strategies",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(s["id"] == strategy_id for s in resp.json())


def test_strategy_duplicate_version_409(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)

    body = {"name": "dup-strat", "version": "1.0", "strategy_type": "momentum"}
    resp = client.post(
        f"/api/tenants/{tenant.id}/strategies",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategies",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 409


def test_platform_strategy_visible(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)

    platform_strategy = Strategy(
        tenant_id=None,
        name="platform-strat",
        version="1.0",
        strategy_type="mean_reversion",
    )
    db.add(platform_strategy)
    db.flush()

    resp = client.get(
        f"/api/tenants/{tenant.id}/strategies",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(s["name"] == "platform-strat" for s in resp.json())


# --- StrategyConfig tests ------------------------------------------------------


def test_strategy_config_crud(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = create_test_portfolio(db, tenant)
    strategy = _make_strategy(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-configs",
        json={
            "strategy_id": str(strategy.id),
            "portfolio_id": str(portfolio.id),
            "parameters": {"lookback": 30},
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["lifecycle_status"] == "DEVELOPMENT"
    config_id = body["id"]

    resp = client.patch(
        f"/api/tenants/{tenant.id}/strategy-configs/{config_id}",
        json={"lifecycle_status": "BACKTESTED"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["lifecycle_status"] == "BACKTESTED"

    resp = client.get(
        f"/api/tenants/{tenant.id}/strategy-configs",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(c["id"] == config_id for c in resp.json())


def test_strategy_config_invalid_portfolio_404(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    strategy = _make_strategy(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/strategy-configs",
        json={
            "strategy_id": str(strategy.id),
            "portfolio_id": str(uuid.uuid4()),
            "parameters": {},
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 404


# --- Backtest tests ------------------------------------------------------------


@patch("app.routers.backtests.backtest_scheduler")
def test_backtest_submit_and_list(mock_scheduler, client, db):
    mock_scheduler.submit.return_value = True

    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = create_test_portfolio(db, tenant)
    strategy = _make_strategy(db, tenant)
    config = _make_config(db, tenant, strategy, portfolio)

    body = {
        "strategy_config_id": str(config.id),
        "symbol": "RELIANCE",
        "start_date": BASE_TS.isoformat(),
        "end_date": (BASE_TS + timedelta(days=10)).isoformat(),
    }
    resp = client.post(
        f"/api/tenants/{tenant.id}/backtests",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "PENDING"
    backtest_id = resp.json()["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/backtests",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(b["id"] == backtest_id for b in resp.json())

    resp = client.get(
        f"/api/tenants/{tenant.id}/backtests/{backtest_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == backtest_id


@patch("app.routers.backtests.backtest_scheduler")
def test_backtest_quota_exceeded(mock_scheduler, client, db):
    mock_scheduler.submit.return_value = False

    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = create_test_portfolio(db, tenant)
    strategy = _make_strategy(db, tenant)
    config = _make_config(db, tenant, strategy, portfolio)

    body = {
        "strategy_config_id": str(config.id),
        "symbol": "RELIANCE",
        "start_date": BASE_TS.isoformat(),
        "end_date": (BASE_TS + timedelta(days=10)).isoformat(),
    }
    resp = client.post(
        f"/api/tenants/{tenant.id}/backtests",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "FAILED"
    assert "quota" in resp.json()["error_message"]


def test_backtest_invalid_date_range(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = create_test_portfolio(db, tenant)
    strategy = _make_strategy(db, tenant)
    config = _make_config(db, tenant, strategy, portfolio)

    body = {
        "strategy_config_id": str(config.id),
        "symbol": "RELIANCE",
        "start_date": (BASE_TS + timedelta(days=10)).isoformat(),
        "end_date": BASE_TS.isoformat(),
    }
    resp = client.post(
        f"/api/tenants/{tenant.id}/backtests",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 400


def test_backtest_missing_config_404(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)

    body = {
        "strategy_config_id": str(uuid.uuid4()),
        "symbol": "RELIANCE",
        "start_date": BASE_TS.isoformat(),
        "end_date": (BASE_TS + timedelta(days=10)).isoformat(),
    }
    resp = client.post(
        f"/api/tenants/{tenant.id}/backtests",
        json=body,
        headers=auth_header(token),
    )
    assert resp.status_code == 404


# --- Metrics test ----------------------------------------------------------------


def test_calculate_metrics_basic():
    equity_curve = pd.Series([100.0, 105.0, 103.0, 110.0], dtype="float64")
    trades = [
        {"pnl": 5.0, "entry_date": BASE_TS, "exit_date": BASE_TS + timedelta(days=1)},
        {
            "pnl": -2.0,
            "entry_date": BASE_TS + timedelta(days=2),
            "exit_date": BASE_TS + timedelta(days=3),
        },
    ]

    metrics = calculate_metrics(equity_curve, trades)

    expected_keys = {
        "gross_return",
        "net_return",
        "cagr",
        "sharpe",
        "sortino",
        "calmar",
        "max_drawdown",
        "profit_factor",
        "win_rate",
        "avg_winner",
        "avg_loser",
        "expected_value",
        "total_trades",
        "worst_day",
        "best_day",
        "max_losing_streak",
    }
    assert expected_keys.issubset(metrics.keys())
    assert metrics["total_trades"] == 2
    assert metrics["win_rate"] == 0.5
    assert isinstance(metrics["sharpe"], float)
    assert metrics["max_drawdown"] >= 0
    assert metrics["avg_winner"] == 5.0
    assert metrics["avg_loser"] == -2.0
