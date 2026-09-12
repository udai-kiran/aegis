"""End-to-end tests for the Phase 2 API endpoints.

Covers instrument CRUD, OHLCV batch upload/upsert/query, platform and tenant
strategies, tenant-scoped strategy configs, and backtest runs.  All requests
go through the ``/api`` prefix and use the shared fixtures from
``conftest.py``.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta


def _suffix() -> str:
    return uuid.uuid4().hex[:10]


def _create_instrument(
    client, admin_headers, symbol: str | None = None, exchange: str = "NSE"
) -> dict:
    """Create an instrument as the platform admin and return the response body."""
    body = {
        "symbol": symbol or f"TST{_suffix()}",
        "exchange": exchange,
        "instrument_type": "EQUITY",
        "name": f"Test Instrument {symbol or _suffix()}",
        "lot_size": 1,
        "tick_size": 0.05,
    }
    response = client.post("/api/instruments", json=body, headers=admin_headers)
    assert response.status_code == 201, f"Instrument create failed: {response.text}"
    return response.json()


def _create_researcher(client, tenant_with_admin: dict) -> dict:
    """Create a RESEARCHER user in the tenant and return login details."""
    tenant_id = tenant_with_admin["tenant_id"]
    suffix = _suffix()
    email = f"researcher-{suffix}@example.com"
    password = "researcher-pass"

    create_response = client.post(
        f"/api/tenants/{tenant_id}/users",
        json={"email": email, "password": password, "role": "RESEARCHER"},
        headers=tenant_with_admin["headers"],
    )
    assert (
        create_response.status_code == 201
    ), f"Researcher create failed: {create_response.text}"

    login_response = client.post(
        "/api/auth/login", json={"email": email, "password": password}
    )
    assert (
        login_response.status_code == 200
    ), f"Researcher login failed: {login_response.text}"
    token = login_response.json()["access_token"]

    return {
        "user": create_response.json(),
        "email": email,
        "headers": {"Authorization": f"Bearer {token}"},
    }


def _create_portfolio(client, tenant_with_admin: dict, name: str | None = None) -> dict:
    """Create a portfolio in the tenant (as its admin) and return the response body."""
    response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/portfolios",
        json={"name": name or f"Portfolio {_suffix()}", "starting_capital": 1_000_000},
        headers=tenant_with_admin["headers"],
    )
    assert response.status_code == 201, f"Portfolio create failed: {response.text}"
    return response.json()


def _create_strategy_config(
    client, tenant_with_admin: dict, strategy_id: uuid.UUID, portfolio_id: uuid.UUID
) -> dict:
    """Create a strategy config linking a strategy to a portfolio (as tenant admin)."""
    response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/strategy-configs",
        json={
            "portfolio_id": str(portfolio_id),
            "strategy_id": str(strategy_id),
            "parameters": {"lookback": 20},
            "lifecycle_status": "DEVELOPMENT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert (
        response.status_code == 201
    ), f"Strategy config create failed: {response.text}"
    return response.json()


def _create_backtest(
    client, tenant_with_admin: dict, config: dict, portfolio_id: uuid.UUID
) -> dict:
    """Create a backtest run from an existing strategy config and return the body."""
    response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/backtests",
        json={
            "portfolio_id": str(portfolio_id),
            "strategy_config_id": str(config["id"]),
            "start_date": "2024-01-01",
            "end_date": "2024-03-31",
            "timeframe": "1d",
            "parameters": {"capital": 100000},
        },
        headers=tenant_with_admin["headers"],
    )
    assert response.status_code == 201, f"Backtest create failed: {response.text}"
    return response.json()


# --- Instruments ---


def test_instrument_create(client, admin_headers):
    """Platform admin creates an instrument, returns 201 with the right fields."""
    body = {
        "symbol": f"NEW{_suffix()}",
        "exchange": "NSE",
        "instrument_type": "EQUITY",
        "name": "Phase 2 Instrument",
        "lot_size": 10,
        "tick_size": 0.05,
    }
    response = client.post("/api/instruments", json=body, headers=admin_headers)
    assert (
        response.status_code == 201
    ), f"Expected 201 on instrument create, got {response.status_code}: {response.text}"

    instrument = response.json()
    assert instrument["symbol"] == body["symbol"], "Created instrument symbol mismatch"
    assert instrument["exchange"] == "NSE", "Created instrument exchange mismatch"
    assert instrument["is_active"] is True, "New instrument should be active"
    assert instrument["id"], "Instrument response should include an id"


def test_instrument_list(client, admin_headers):
    """Any authenticated user can list active instruments."""
    created = _create_instrument(client, admin_headers)

    response = client.get("/api/instruments", headers=admin_headers)
    assert (
        response.status_code == 200
    ), f"Expected 200 on instrument list, got {response.status_code}: {response.text}"

    instruments = response.json()
    ids = [i["id"] for i in instruments]
    assert created["id"] in ids, "Created instrument should appear in the list"
    assert all(
        i["is_active"] for i in instruments
    ), "Only active instruments should be listed"


def test_instrument_get(client, admin_headers, tenant_with_admin):
    """A single instrument can be fetched by ID by any auth user."""
    created = _create_instrument(client, admin_headers)

    # Tenant admin (non-platform-admin) can also read it.
    response = client.get(
        f"/api/instruments/{created['id']}", headers=tenant_with_admin["headers"]
    )
    assert (
        response.status_code == 200
    ), f"Expected 200 on instrument get, got {response.status_code}: {response.text}"
    assert response.json()["id"] == created["id"], "Fetched instrument id mismatch"

    missing = client.get(f"/api/instruments/{uuid.uuid4()}", headers=admin_headers)
    assert (
        missing.status_code == 404
    ), f"Unknown instrument should 404, got {missing.status_code}"


def test_instrument_duplicate_symbol_exchange(client, admin_headers):
    """Creating an instrument with the same symbol+exchange returns 409."""
    body = {
        "symbol": f"DUP{_suffix()}",
        "exchange": "BSE",
        "instrument_type": "EQUITY",
        "name": "Duplicate Instrument",
    }
    first = client.post("/api/instruments", json=body, headers=admin_headers)
    assert first.status_code == 201, f"First create should succeed: {first.text}"

    second = client.post("/api/instruments", json=body, headers=admin_headers)
    assert (
        second.status_code == 409
    ), f"Duplicate symbol+exchange should return 409, got {second.status_code}: {second.text}"


def test_instrument_create_requires_platform_admin(client, tenant_with_admin):
    """Non-admin users cannot create instruments (403)."""
    body = {
        "symbol": f"NONADM{_suffix()}"[:20],
        "exchange": "NSE",
        "instrument_type": "EQUITY",
        "name": "Forbidden Instrument",
    }
    response = client.post(
        "/api/instruments", json=body, headers=tenant_with_admin["headers"]
    )
    assert (
        response.status_code == 403
    ), f"TENANT_ADMIN creating an instrument should get 403, got {response.status_code}: {response.text}"


# --- OHLCV ---


def test_ohlcv_upload_and_upserted_count(client, admin_headers):
    """Platform admin batch-uploads OHLCV bars; the response reports the count."""
    instrument = _create_instrument(client, admin_headers)
    base = datetime(2024, 1, 1, 0, 0, 0)
    bars = [
        {
            "timeframe": "1d",
            "timestamp": (base + timedelta(days=i)).isoformat(),
            "open": 100.0 + i,
            "high": 105.0 + i,
            "low": 99.0 + i,
            "close": 102.0 + i,
            "volume": 1000 + i,
        }
        for i in range(5)
    ]

    response = client.post(
        f"/api/instruments/{instrument['id']}/ohlcv", json=bars, headers=admin_headers
    )
    assert response.status_code == 201, f"OHLCV upload failed: {response.text}"
    assert response.json() == {
        "upserted": 5
    }, f"Expected upserted=5, got {response.json()}"


def test_ohlcv_upsert_updates_not_duplicates(client, admin_headers):
    """Uploading the same timestamp twice updates the bar instead of duplicating."""
    instrument = _create_instrument(client, admin_headers)
    ts = datetime(2024, 2, 1, 9, 15, 0).isoformat()
    bar_first = {
        "timeframe": "1d",
        "timestamp": ts,
        "open": 50.0,
        "high": 55.0,
        "low": 49.0,
        "close": 52.0,
        "volume": 100,
    }
    bar_second = {
        "timeframe": "1d",
        "timestamp": ts,
        "open": 50.0,
        "high": 60.0,
        "low": 49.5,
        "close": 58.0,
        "volume": 250,
    }

    first = client.post(
        f"/api/instruments/{instrument['id']}/ohlcv",
        json=[bar_first],
        headers=admin_headers,
    )
    assert first.status_code == 201, f"First upload failed: {first.text}"

    second = client.post(
        f"/api/instruments/{instrument['id']}/ohlcv",
        json=[bar_second],
        headers=admin_headers,
    )
    assert second.status_code == 201, f"Second upload failed: {second.text}"
    assert second.json() == {"upserted": 1}, "Re-upload should report 1 upserted bar"

    query = client.get(
        f"/api/instruments/{instrument['id']}/ohlcv", headers=admin_headers
    )
    assert query.status_code == 200, f"OHLCV query failed: {query.text}"
    bars = query.json()
    assert len(bars) == 1, f"Upsert should not duplicate bars, found {len(bars)}"
    assert (
        bars[0]["close"] == 58.0
    ), f"Bar should hold updated close, got {bars[0]['close']}"
    assert (
        bars[0]["volume"] == 250
    ), f"Bar should hold updated volume, got {bars[0]['volume']}"


def test_ohlcv_query_timeframe_filter(client, admin_headers, tenant_with_admin):
    """Querying bars returns only those matching the requested timeframe."""
    instrument = _create_instrument(client, admin_headers)
    ts = datetime(2024, 3, 1, 9, 15, 0).isoformat()
    daily = {
        "timeframe": "1d",
        "timestamp": ts,
        "open": 10.0,
        "high": 11.0,
        "low": 9.5,
        "close": 10.5,
        "volume": 500,
    }
    intraday = {
        "timeframe": "1h",
        "timestamp": ts,
        "open": 10.0,
        "high": 10.8,
        "low": 9.8,
        "close": 10.2,
        "volume": 120,
    }
    upload = client.post(
        f"/api/instruments/{instrument['id']}/ohlcv",
        json=[daily, intraday],
        headers=admin_headers,
    )
    assert upload.status_code == 201, f"OHLCV upload failed: {upload.text}"

    # Default query (timeframe=1d) returns only the daily bar.
    response = client.get(
        f"/api/instruments/{instrument['id']}/ohlcv",
        headers=tenant_with_admin["headers"],
    )
    assert response.status_code == 200, f"OHLCV query failed: {response.text}"
    bars = response.json()
    assert len(bars) == 1, f"1d query should return exactly one bar, got {len(bars)}"
    assert (
        bars[0]["timeframe"] == "1d"
    ), f"Wrong timeframe returned: {bars[0]['timeframe']}"
    assert bars[0]["close"] == 10.5, "Returned bar data mismatch"

    hourly = client.get(
        f"/api/instruments/{instrument['id']}/ohlcv?timeframe=1h",
        headers=tenant_with_admin["headers"],
    )
    assert hourly.status_code == 200, f"1h query failed: {hourly.text}"
    hourly_bars = hourly.json()
    assert (
        len(hourly_bars) == 1 and hourly_bars[0]["timeframe"] == "1h"
    ), "1h query should return only the hourly bar"


def test_ohlcv_query_date_range(client, admin_headers):
    """Query with start/end filters returns only bars inside the range."""
    instrument = _create_instrument(client, admin_headers)
    base = datetime(2024, 5, 1, 0, 0, 0)
    bars = [
        {
            "timeframe": "1d",
            "timestamp": (base + timedelta(days=i)).isoformat(),
            "open": 100.0,
            "high": 101.0,
            "low": 99.0,
            "close": 100.5,
            "volume": 10 + i,
        }
        for i in range(10)  # 2024-05-01 .. 2024-05-10
    ]
    upload = client.post(
        f"/api/instruments/{instrument['id']}/ohlcv", json=bars, headers=admin_headers
    )
    assert upload.status_code == 201, f"OHLCV upload failed: {upload.text}"

    params = {"start": "2024-05-03T00:00:00", "end": "2024-05-06T00:00:00"}
    response = client.get(
        f"/api/instruments/{instrument['id']}/ohlcv",
        params=params,
        headers=admin_headers,
    )
    assert response.status_code == 200, f"Date-range query failed: {response.text}"
    bars_in_range = response.json()
    timestamps = [b["timestamp"] for b in bars_in_range]
    assert (
        len(bars_in_range) == 4
    ), f"Expected 4 bars in range, got {len(bars_in_range)}: {timestamps}"
    assert all(
        "2024-05-03" <= t[:10] <= "2024-05-06" for t in timestamps
    ), f"Bars outside the requested range were returned: {timestamps}"


# --- Strategies ---


def test_platform_strategy_create(client, admin_headers):
    """Platform admin creates a PLATFORM-owned strategy."""
    response = client.post(
        "/api/strategies",
        json={
            "name": f"Platform Strategy {_suffix()}",
            "description": "Owned by the platform",
            "version": "1.0.0",
            "owner_type": "PLATFORM",
            "code_reference": "platform:strategies:momentum",
        },
        headers=admin_headers,
    )
    assert (
        response.status_code == 201
    ), f"Platform strategy create failed: {response.text}"
    strategy = response.json()
    assert strategy["owner_type"] == "PLATFORM", "owner_type should be PLATFORM"
    assert (
        strategy["tenant_id"] is None
    ), "Platform strategies must not have a tenant_id"


def test_tenant_strategy_create(client, tenant_with_admin):
    """A RESEARCHER in the tenant creates a TENANT-owned strategy."""
    researcher = _create_researcher(client, tenant_with_admin)

    response = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Tenant Strategy {_suffix()}",
            "owner_type": "TENANT",
            "code_reference": f"tenant:{tenant_with_admin['tenant_id']}:alpha",
        },
        headers=researcher["headers"],
    )
    assert (
        response.status_code == 201
    ), f"Tenant strategy create failed: {response.text}"
    strategy = response.json()
    assert strategy["owner_type"] == "TENANT", "owner_type should be TENANT"
    assert (
        strategy["tenant_id"] == tenant_with_admin["tenant_id"]
    ), "Strategy should belong to the tenant"


def test_strategy_list_visibility(client, admin_headers, tenant_with_admin):
    """Researchers see platform strategies + their own tenant's, not other tenants'."""
    platform = client.post(
        "/api/strategies",
        json={
            "name": f"Visible Platform Strategy {_suffix()}",
            "owner_type": "PLATFORM",
        },
        headers=admin_headers,
    )
    assert (
        platform.status_code == 201
    ), f"Platform strategy create failed: {platform.text}"

    own = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Own Tenant Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert own.status_code == 201, f"Own tenant strategy create failed: {own.text}"

    # Second tenant, to hold a strategy the researcher must NOT see.
    other_tenant = client.post(
        "/api/tenants",
        json={"name": f"Other Tenant {_suffix()}"},
        headers=admin_headers,
    )
    assert (
        other_tenant.status_code == 201
    ), f"Other tenant create failed: {other_tenant.text}"
    foreign = client.post(
        "/api/strategies",
        json={
            "tenant_id": other_tenant.json()["id"],
            "name": f"Foreign Tenant Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=admin_headers,
    )
    assert foreign.status_code == 201, f"Foreign strategy create failed: {foreign.text}"

    researcher = _create_researcher(client, tenant_with_admin)
    response = client.get("/api/strategies", headers=researcher["headers"])
    assert response.status_code == 200, f"Strategy list failed: {response.text}"

    strategies = response.json()
    names = [s["name"] for s in strategies]
    assert (
        platform.json()["name"] in names
    ), "Platform strategy should be visible to researchers"
    assert own.json()["name"] in names, "Own tenant strategy should be visible"
    assert (
        foreign.json()["name"] not in names
    ), "Another tenant's strategy must not be visible"


def test_strategy_update(client, admin_headers):
    """Platform admin updates a platform strategy's version."""
    created = client.post(
        "/api/strategies",
        json={
            "name": f"Updatable Strategy {_suffix()}",
            "version": "1.0.0",
            "owner_type": "PLATFORM",
        },
        headers=admin_headers,
    )
    assert created.status_code == 201, f"Strategy create failed: {created.text}"
    strategy_id = created.json()["id"]

    response = client.patch(
        f"/api/strategies/{strategy_id}",
        json={"version": "2.0.0", "description": "Bumped to v2"},
        headers=admin_headers,
    )
    assert response.status_code == 200, f"Strategy update failed: {response.text}"
    updated = response.json()
    assert (
        updated["version"] == "2.0.0"
    ), f"Version was not updated: {updated['version']}"
    assert updated["description"] == "Bumped to v2", "Description was not updated"


# --- Strategy configs ---


def test_strategy_config_create(client, admin_headers, tenant_with_admin):
    """Create a config linking a strategy to a portfolio inside a tenant."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Config Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"

    response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/strategy-configs",
        json={
            "portfolio_id": portfolio["id"],
            "strategy_id": strategy.json()["id"],
            "parameters": {"lookback": 20, "threshold": 1.5},
            "lifecycle_status": "DEVELOPMENT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert (
        response.status_code == 201
    ), f"Strategy config create failed: {response.text}"
    config = response.json()
    assert (
        config["portfolio_id"] == portfolio["id"]
    ), "Config should reference the portfolio"
    assert (
        config["strategy_id"] == strategy.json()["id"]
    ), "Config should reference the strategy"
    assert (
        config["tenant_id"] == tenant_with_admin["tenant_id"]
    ), "Config should be tenant-scoped"
    assert (
        config["lifecycle_status"] == "DEVELOPMENT"
    ), "Default lifecycle status mismatch"
    assert config["is_active"] is True, "New config should be active"


def test_strategy_config_update(client, tenant_with_admin):
    """Update parameters and lifecycle_status of a config."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Updatable Config Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    config = _create_strategy_config(
        client, tenant_with_admin, strategy.json()["id"], portfolio["id"]
    )

    response = client.patch(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/strategy-configs/{config['id']}",
        json={"parameters": {"lookback": 50}, "lifecycle_status": "PRODUCTION"},
        headers=tenant_with_admin["headers"],
    )
    assert (
        response.status_code == 200
    ), f"Strategy config update failed: {response.text}"
    updated = response.json()
    assert updated["parameters"] == {
        "lookback": 50
    }, f"Parameters were not updated: {updated['parameters']}"
    assert (
        updated["lifecycle_status"] == "PRODUCTION"
    ), "lifecycle_status was not updated"


def test_strategy_config_delete(client, tenant_with_admin):
    """Delete returns 204; a subsequent get returns 404."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Deletable Config Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    config = _create_strategy_config(
        client, tenant_with_admin, strategy.json()["id"], portfolio["id"]
    )

    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]
    delete_response = client.delete(
        f"/api/tenants/{tenant_id}/strategy-configs/{config['id']}", headers=headers
    )
    assert (
        delete_response.status_code == 204
    ), f"Delete should return 204, got {delete_response.status_code}: {delete_response.text}"

    get_response = client.get(
        f"/api/tenants/{tenant_id}/strategy-configs/{config['id']}", headers=headers
    )
    assert (
        get_response.status_code == 404
    ), f"Deleted config should 404, got {get_response.status_code}"


def test_strategy_config_cross_tenant_validation(
    client, admin_headers, tenant_with_admin
):
    """A config cannot reference another tenant's portfolio or tenant strategy."""
    # First tenant (from the fixture) owns the portfolio and tenant strategy.
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Cross Tenant Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"

    # Second tenant, whose admin attempts to use the first tenant's resources.
    other_tenant = client.post(
        "/api/tenants",
        json={"name": f"Cross Tenant {_suffix()}"},
        headers=admin_headers,
    )
    assert (
        other_tenant.status_code == 201
    ), f"Other tenant create failed: {other_tenant.text}"
    other_tenant_id = other_tenant.json()["id"]

    other_admin_email = f"other-admin-{_suffix()}@example.com"
    user_response = client.post(
        f"/api/tenants/{other_tenant_id}/users",
        json={
            "email": other_admin_email,
            "password": "other-admin-pass",
            "role": "TENANT_ADMIN",
        },
        headers=admin_headers,
    )
    assert (
        user_response.status_code == 201
    ), f"Other tenant admin create failed: {user_response.text}"
    login_response = client.post(
        "/api/auth/login",
        json={"email": other_admin_email, "password": "other-admin-pass"},
    )
    assert (
        login_response.status_code == 200
    ), f"Other tenant admin login failed: {login_response.text}"
    other_headers = {"Authorization": f"Bearer {login_response.json()['access_token']}"}

    # Foreign portfolio rejected.
    portfolio_attempt = client.post(
        f"/api/tenants/{other_tenant_id}/strategy-configs",
        json={"portfolio_id": portfolio["id"], "strategy_id": strategy.json()["id"]},
        headers=other_headers,
    )
    assert (
        portfolio_attempt.status_code == 404
    ), f"Foreign portfolio should be rejected (404), got {portfolio_attempt.status_code}: {portfolio_attempt.text}"

    # Foreign tenant strategy rejected.
    own_other_portfolio = _create_portfolio(
        client, {"tenant_id": other_tenant_id, "headers": other_headers}
    )
    strategy_attempt = client.post(
        f"/api/tenants/{other_tenant_id}/strategy-configs",
        json={
            "portfolio_id": own_other_portfolio["id"],
            "strategy_id": strategy.json()["id"],
        },
        headers=other_headers,
    )
    assert (
        strategy_attempt.status_code == 403
    ), f"Foreign tenant strategy should be rejected (403), got {strategy_attempt.status_code}: {strategy_attempt.text}"


# --- Backtests ---


def test_backtest_create(client, tenant_with_admin):
    """A researcher creates a backtest run; it starts as PENDING."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Backtest Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    config = _create_strategy_config(
        client, tenant_with_admin, strategy.json()["id"], portfolio["id"]
    )

    researcher = _create_researcher(client, tenant_with_admin)
    response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/backtests",
        json={
            "portfolio_id": portfolio["id"],
            "strategy_config_id": config["id"],
            "start_date": "2024-01-01",
            "end_date": "2024-06-30",
            "timeframe": "1d",
        },
        headers=researcher["headers"],
    )
    assert response.status_code == 201, f"Backtest create failed: {response.text}"
    backtest = response.json()
    assert (
        backtest["status"] == "PENDING"
    ), f"New backtest should be PENDING, got {backtest['status']}"
    assert backtest["start_date"] == "2024-01-01", "start_date mismatch"
    assert backtest["end_date"] == "2024-06-30", "end_date mismatch"
    assert backtest["metrics"] is None, "New backtest should have no metrics yet"


def test_backtest_invalid_date_range(client, tenant_with_admin):
    """start_date >= end_date returns 400."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Invalid Dates Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    config = _create_strategy_config(
        client, tenant_with_admin, strategy.json()["id"], portfolio["id"]
    )

    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]

    # start == end
    equal_dates = client.post(
        f"/api/tenants/{tenant_id}/backtests",
        json={
            "portfolio_id": portfolio["id"],
            "strategy_config_id": config["id"],
            "start_date": "2024-03-01",
            "end_date": "2024-03-01",
        },
        headers=headers,
    )
    assert (
        equal_dates.status_code == 400
    ), f"start_date == end_date should return 400, got {equal_dates.status_code}: {equal_dates.text}"

    # start > end
    reversed_dates = client.post(
        f"/api/tenants/{tenant_id}/backtests",
        json={
            "portfolio_id": portfolio["id"],
            "strategy_config_id": config["id"],
            "start_date": "2024-06-30",
            "end_date": "2024-01-01",
        },
        headers=headers,
    )
    assert (
        reversed_dates.status_code == 400
    ), f"start_date > end_date should return 400, got {reversed_dates.status_code}: {reversed_dates.text}"


def test_backtest_list_and_get(client, tenant_with_admin):
    """List backtests (with optional filters) and fetch one by ID."""
    portfolio_a = _create_portfolio(client, tenant_with_admin)
    portfolio_b = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"List Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    strategy_id = strategy.json()["id"]
    config_a = _create_strategy_config(
        client, tenant_with_admin, strategy_id, portfolio_a["id"]
    )
    config_b = _create_strategy_config(
        client, tenant_with_admin, strategy_id, portfolio_b["id"]
    )
    backtest_a = _create_backtest(
        client, tenant_with_admin, config_a, portfolio_a["id"]
    )
    backtest_b = _create_backtest(
        client, tenant_with_admin, config_b, portfolio_b["id"]
    )

    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]

    # Plain list contains both.
    list_response = client.get(f"/api/tenants/{tenant_id}/backtests", headers=headers)
    assert (
        list_response.status_code == 200
    ), f"Backtest list failed: {list_response.text}"
    listed_ids = [b["id"] for b in list_response.json()]
    assert backtest_a["id"] in listed_ids, "Backtest A missing from list"
    assert backtest_b["id"] in listed_ids, "Backtest B missing from list"

    # Filter by portfolio_id.
    filtered = client.get(
        f"/api/tenants/{tenant_id}/backtests",
        params={"portfolio_id": portfolio_a["id"]},
        headers=headers,
    )
    assert (
        filtered.status_code == 200
    ), f"Filtered backtest list failed: {filtered.text}"
    filtered_ids = [b["id"] for b in filtered.json()]
    assert filtered_ids == [
        backtest_a["id"]
    ], f"portfolio_id filter should return only backtest A: {filtered_ids}"

    # Filter by status.
    by_status = client.get(
        f"/api/tenants/{tenant_id}/backtests",
        params={"status": "PENDING"},
        headers=headers,
    )
    assert (
        by_status.status_code == 200
    ), f"Status-filtered list failed: {by_status.text}"
    status_ids = [b["id"] for b in by_status.json()]
    assert (
        backtest_a["id"] in status_ids and backtest_b["id"] in status_ids
    ), "Both PENDING backtests should be listed"

    # Get single.
    get_response = client.get(
        f"/api/tenants/{tenant_id}/backtests/{backtest_a['id']}", headers=headers
    )
    assert get_response.status_code == 200, f"Backtest get failed: {get_response.text}"
    assert get_response.json()["id"] == backtest_a["id"], "Fetched backtest id mismatch"

    # Unknown id -> 404.
    missing = client.get(
        f"/api/tenants/{tenant_id}/backtests/{uuid.uuid4()}", headers=headers
    )
    assert (
        missing.status_code == 404
    ), f"Unknown backtest should 404, got {missing.status_code}"


def test_backtest_tenant_isolation(client, admin_headers, tenant_with_admin):
    """A user from another tenant cannot see (or create in) another tenant's backtests."""
    portfolio = _create_portfolio(client, tenant_with_admin)
    strategy = client.post(
        "/api/strategies",
        json={
            "tenant_id": tenant_with_admin["tenant_id"],
            "name": f"Isolated Strategy {_suffix()}",
            "owner_type": "TENANT",
        },
        headers=tenant_with_admin["headers"],
    )
    assert strategy.status_code == 201, f"Strategy create failed: {strategy.text}"
    config = _create_strategy_config(
        client, tenant_with_admin, strategy.json()["id"], portfolio["id"]
    )
    backtest = _create_backtest(client, tenant_with_admin, config, portfolio["id"])

    # Foreign tenant + RESEARCHER user.
    other_tenant = client.post(
        "/api/tenants",
        json={"name": f"Isolation Tenant {_suffix()}"},
        headers=admin_headers,
    )
    assert (
        other_tenant.status_code == 201
    ), f"Other tenant create failed: {other_tenant.text}"
    other_tenant_id = other_tenant.json()["id"]
    researcher_email = f"foreign-researcher-{_suffix()}@example.com"
    user_response = client.post(
        f"/api/tenants/{other_tenant_id}/users",
        json={
            "email": researcher_email,
            "password": "foreign-pass-123",
            "role": "RESEARCHER",
        },
        headers=admin_headers,
    )
    assert (
        user_response.status_code == 201
    ), f"Foreign researcher create failed: {user_response.text}"
    login_response = client.post(
        "/api/auth/login",
        json={"email": researcher_email, "password": "foreign-pass-123"},
    )
    assert (
        login_response.status_code == 200
    ), f"Foreign researcher login failed: {login_response.text}"
    foreign_headers = {
        "Authorization": f"Bearer {login_response.json()['access_token']}"
    }

    # List is tenant-scoped: 403 for a foreign tenant id.
    list_response = client.get(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/backtests",
        headers=foreign_headers,
    )
    assert (
        list_response.status_code == 403
    ), f"Foreign user listing another tenant's backtests should get 403, got {list_response.status_code}: {list_response.text}"

    # Get is also tenant-scoped.
    get_response = client.get(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/backtests/{backtest['id']}",
        headers=foreign_headers,
    )
    assert (
        get_response.status_code == 403
    ), f"Foreign user fetching another tenant's backtest should get 403, got {get_response.status_code}: {get_response.text}"

    # Creating in a foreign tenant is rejected too.
    create_response = client.post(
        f"/api/tenants/{tenant_with_admin['tenant_id']}/backtests",
        json={
            "portfolio_id": portfolio["id"],
            "strategy_config_id": config["id"],
            "start_date": "2024-01-01",
            "end_date": "2024-02-01",
        },
        headers=foreign_headers,
    )
    assert (
        create_response.status_code == 403
    ), f"Foreign user creating in another tenant should get 403, got {create_response.status_code}: {create_response.text}"
