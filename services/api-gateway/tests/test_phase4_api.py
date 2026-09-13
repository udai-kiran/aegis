"""Phase 4 API tests: broker accounts, kill switch, execution, reconciliation."""

from __future__ import annotations

import uuid

from app.models import BrokerAccount, Portfolio
from tests.conftest import (
    auth_header,
    create_platform_admin,
    create_test_tenant,
    create_test_user,
)


def _make_broker_account(
    db, tenant, broker_type="ZERODHA", credentials=None
) -> BrokerAccount:
    """Create a broker account directly in the DB for testing."""
    from app.broker.credential_vault import encrypt_credentials

    encrypted = encrypt_credentials(credentials) if credentials else None
    account = BrokerAccount(
        tenant_id=tenant.id,
        broker_type=broker_type,
        display_name=f"test-account-{uuid.uuid4().hex[:8]}",
        encrypted_credentials=encrypted,
        credential_metadata={"client_id": "test123"} if credentials else None,
        status="ACTIVE",
    )
    db.add(account)
    db.flush()
    return account


def _make_live_portfolio(db, tenant, capital=100000.0) -> Portfolio:
    """Create a LIVE trading mode portfolio."""
    portfolio = Portfolio(
        tenant_id=tenant.id,
        name=f"live-portfolio-{uuid.uuid4().hex[:8]}",
        starting_capital=capital,
        current_equity=capital,
        cash=capital,
        trading_mode="LIVE",
    )
    db.add(portfolio)
    db.flush()
    return portfolio


# --- Broker Account tests ------------------------------------------------------


def test_broker_account_crud(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.post(
        f"/api/tenants/{tenant.id}/broker-accounts",
        json={
            "broker_type": "ZERODHA",
            "display_name": "my-zerodha",
            "credentials": {"api_key": "key123", "secret": "sec456"},
            "credential_metadata": {"client_id": "XY1234"},
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["broker_type"] == "ZERODHA"
    assert body["display_name"] == "my-zerodha"
    assert body["credential_metadata"] == {"client_id": "XY1234"}
    # Security: encrypted credentials and raw credentials must never be exposed
    assert "encrypted_credentials" not in body
    assert "credentials" not in body
    account_id = body["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/broker-accounts",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(a["id"] == account_id for a in resp.json())

    resp = client.get(
        f"/api/tenants/{tenant.id}/broker-accounts/{account_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == account_id

    resp = client.patch(
        f"/api/tenants/{tenant.id}/broker-accounts/{account_id}",
        json={"display_name": "renamed-account"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["display_name"] == "renamed-account"

    resp = client.delete(
        f"/api/tenants/{tenant.id}/broker-accounts/{account_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 204

    # Delete is a soft delete (status=INACTIVE); the list endpoint returns
    # ALL accounts, so verify the status flips rather than disappearance.
    resp = client.get(
        f"/api/tenants/{tenant.id}/broker-accounts",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    account = next(a for a in resp.json() if a["id"] == account_id)
    assert account["status"] == "INACTIVE"


def test_broker_account_cross_tenant_denied(client, db):
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user, token = create_test_user(db, tenant_a, role="TENANT_ADMIN")
    _make_broker_account(db, tenant_b)

    resp = client.get(
        f"/api/tenants/{tenant_b.id}/broker-accounts",
        headers=auth_header(token),
    )
    assert resp.status_code == 403


# --- Kill Switch tests ---------------------------------------------------------


def test_kill_switch_tenant_halt(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["tenant_halted"] is False

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={"scope": "TENANT", "action": "HALT"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["tenant_halted"] is True

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={"scope": "TENANT", "action": "RESUME"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["tenant_halted"] is False


def test_kill_switch_portfolio_halt(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = _make_live_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={"scope": "PORTFOLIO", "target_id": str(portfolio.id), "action": "HALT"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert str(portfolio.id) in resp.json()["portfolios_halted"]

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={"scope": "PORTFOLIO", "target_id": str(portfolio.id), "action": "RESUME"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["portfolios_halted"] == []


def test_kill_switch_broker_account_halt(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    account = _make_broker_account(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={
            "scope": "BROKER_ACCOUNT",
            "target_id": str(account.id),
            "action": "HALT",
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert str(account.id) in resp.json()["broker_accounts_halted"]


def test_emergency_halt(client, db):
    tenant = create_test_tenant(db)
    _admin, admin_token = create_platform_admin(db)
    portfolio = _make_live_portfolio(db, tenant)
    account = _make_broker_account(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch/emergency-halt",
        headers=auth_header(admin_token),
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "halted", "scope": "ALL"}

    resp = client.get(
        f"/api/tenants/{tenant.id}/kill-switch",
        headers=auth_header(admin_token),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["tenant_halted"] is True
    assert str(portfolio.id) in body["portfolios_halted"]
    assert str(account.id) in body["broker_accounts_halted"]


# --- Execution tests -----------------------------------------------------------


def test_execution_buy_creates_position(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = _make_live_portfolio(db, tenant)
    account = _make_broker_account(db, tenant, credentials={"api_key": "test"})

    resp = client.post(
        f"/api/tenants/{tenant.id}/execution/orders",
        json={
            "portfolio_id": str(portfolio.id),
            "broker_account_id": str(account.id),
            "symbol": "RELIANCE",
            "side": "BUY",
            "quantity": 10,
            "price": 100.0,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "FILLED"

    resp = client.get(
        f"/api/tenants/{tenant.id}/portfolios/{portfolio.id}/positions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    positions = resp.json()
    assert len(positions) == 1
    assert positions[0]["symbol"] == "RELIANCE"
    assert positions[0]["quantity"] == 10


def test_execution_halted_tenant_rejected(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = _make_live_portfolio(db, tenant)
    account = _make_broker_account(db, tenant, credentials={"api_key": "test"})

    resp = client.post(
        f"/api/tenants/{tenant.id}/kill-switch",
        json={"scope": "TENANT", "action": "HALT"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200

    resp = client.post(
        f"/api/tenants/{tenant.id}/execution/orders",
        json={
            "portfolio_id": str(portfolio.id),
            "broker_account_id": str(account.id),
            "symbol": "RELIANCE",
            "side": "BUY",
            "quantity": 10,
            "price": 100.0,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 400
    assert "halt" in resp.json()["detail"].lower()


def test_execution_orders_list(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = _make_live_portfolio(db, tenant)
    account = _make_broker_account(db, tenant, credentials={"api_key": "test"})

    resp = client.post(
        f"/api/tenants/{tenant.id}/execution/orders",
        json={
            "portfolio_id": str(portfolio.id),
            "broker_account_id": str(account.id),
            "symbol": "RELIANCE",
            "side": "BUY",
            "quantity": 10,
            "price": 100.0,
        },
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.get(
        f"/api/tenants/{tenant.id}/execution/orders",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    orders = resp.json()
    assert len(orders) == 1
    assert orders[0]["source"] != "PAPER"


def test_reconciliation(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    account = _make_broker_account(db, tenant, credentials={"api_key": "test"})

    resp = client.post(
        f"/api/tenants/{tenant.id}/execution/reconcile/{account.id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "MATCHED"
