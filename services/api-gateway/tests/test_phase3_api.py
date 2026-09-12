"""Phase 3 API tests: risk policies, paper trading, orders, dashboard, positions."""

from __future__ import annotations

import uuid

from app.models import Portfolio
from tests.conftest import (
    auth_header,
    create_test_tenant,
    create_test_user,
)


def _make_paper_portfolio(db, tenant, capital=100000.0) -> Portfolio:
    portfolio = Portfolio(
        tenant_id=tenant.id,
        name=f"paper-portfolio-{uuid.uuid4().hex[:8]}",
        starting_capital=capital,
        current_equity=capital,
        cash=capital,
        trading_mode="PAPER",
    )
    db.add(portfolio)
    db.flush()
    return portfolio


def _paper_order_payload(portfolio, side="BUY", quantity=10, price=100.0,
                         symbol="RELIANCE"):
    return {
        "portfolio_id": str(portfolio.id),
        "symbol": symbol,
        "side": side,
        "quantity": quantity,
        "price": price,
    }


# --- Risk Policy tests ---------------------------------------------------------


def test_risk_policy_crud(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.post(
        f"/api/tenants/{tenant.id}/risk-policies",
        json={"name": "tenant-wide-policy", "max_order_value": 1000.0},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    policy_id = resp.json()["id"]

    resp = client.get(
        f"/api/tenants/{tenant.id}/risk-policies",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert any(p["id"] == policy_id for p in resp.json())

    resp = client.get(
        f"/api/tenants/{tenant.id}/risk-policies/{policy_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "tenant-wide-policy"

    resp = client.patch(
        f"/api/tenants/{tenant.id}/risk-policies/{policy_id}",
        json={"max_order_value": 2000.0},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json()["max_order_value"] == 2000.0

    resp = client.delete(
        f"/api/tenants/{tenant.id}/risk-policies/{policy_id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 204

    resp = client.get(
        f"/api/tenants/{tenant.id}/risk-policies",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert not any(p["id"] == policy_id for p in resp.json())


def test_risk_policy_portfolio_validation(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")

    resp = client.post(
        f"/api/tenants/{tenant.id}/risk-policies",
        json={"name": "bad-portfolio", "portfolio_id": str(uuid.uuid4())},
        headers=auth_header(token),
    )
    assert resp.status_code == 404


def test_risk_policy_requires_admin(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="VIEWER")

    resp = client.post(
        f"/api/tenants/{tenant.id}/risk-policies",
        json={"name": "viewer-policy"},
        headers=auth_header(token),
    )
    assert resp.status_code != 201


def test_risk_manager_can_create_policy(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="RISK_MANAGER")

    resp = client.post(
        f"/api/tenants/{tenant.id}/risk-policies",
        json={"name": "risk-manager-policy", "max_order_value": 1000.0},
        headers=auth_header(token),
    )
    assert resp.status_code == 201


# --- Paper Trading tests -------------------------------------------------------


def test_paper_order_buy_creates_position(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, quantity=10, price=100.0),
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
    assert positions[0]["quantity"] == 10


def test_paper_order_sell_reduces_position(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, quantity=10, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "FILLED"

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, side="SELL", quantity=5, price=100.0),
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
    assert positions[0]["quantity"] == 5

    # Selling the remaining quantity removes the position entirely
    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, side="SELL", quantity=5, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "FILLED"

    resp = client.get(
        f"/api/tenants/{tenant.id}/portfolios/{portfolio.id}/positions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    assert resp.json() == []


def test_paper_order_non_paper_portfolio_400(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = Portfolio(
        tenant_id=tenant.id,
        name="backtest-portfolio",
        starting_capital=100000.0,
        current_equity=100000.0,
        cash=100000.0,
        trading_mode="BACKTEST",
    )
    db.add(portfolio)
    db.flush()

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio),
        headers=auth_header(token),
    )
    assert resp.status_code == 400


def test_paper_order_risk_rejection(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant, role="TENANT_ADMIN")
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/risk-policies",
        json={"name": "order-cap", "max_order_value": 500.0},
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, quantity=100, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["status"] == "FILLED"
    assert body["quantity"] < 100
    assert body["quantity"] * body["avg_fill_price"] <= 500.0
    assert body["risk_decision"]["approved"] is True
    assert body["risk_decision"]["approved_quantity"] == body["quantity"]


def test_paper_order_requires_price(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    payload = _paper_order_payload(portfolio)
    del payload["price"]
    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=payload,
        headers=auth_header(token),
    )
    assert resp.status_code == 400


def test_paper_order_negative_price_rejected(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, price=-100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 400
    assert "Price must be positive" in resp.json()["detail"]


def test_paper_order_sell_without_position_rejected(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, side="SELL", quantity=5, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 400
    assert "No position to sell" in resp.json()["detail"]


def test_paper_order_oversell_rejected(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, quantity=5, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, side="SELL", quantity=10, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 400
    assert "Cannot sell" in resp.json()["detail"]


def test_partial_sell_tracks_realized_pnl(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant, capital=100000.0)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, quantity=10, price=100.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio, side="SELL", quantity=5, price=150.0),
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.get(
        f"/api/tenants/{tenant.id}/portfolios/{portfolio.id}/positions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    positions = resp.json()
    assert len(positions) == 1
    assert positions[0]["quantity"] == 5
    # Realized gain from the partial sell: 5 * (150 - 100) = 250
    assert positions[0]["realized_pnl"] == 250.0

    resp = client.get(
        f"/api/tenants/{tenant.id}/dashboard/{portfolio.id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_pnl"] == body["current_equity"] - body["starting_capital"]
    # 250 realized + 250 unrealized on the remaining 5 shares marked at 150
    assert body["total_pnl"] == 500.0


# --- Orders tests --------------------------------------------------------------


def test_orders_list_and_filter(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    for symbol in ("RELIANCE", "TCS"):
        resp = client.post(
            f"/api/tenants/{tenant.id}/paper-orders",
            json=_paper_order_payload(portfolio, symbol=symbol),
            headers=auth_header(token),
        )
        assert resp.status_code == 201

    resp = client.get(
        f"/api/tenants/{tenant.id}/orders",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    orders = resp.json()
    assert len(orders) == 2

    resp = client.get(
        f"/api/tenants/{tenant.id}/orders",
        params={"symbol": "RELIANCE"},
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    filtered = resp.json()
    assert len(filtered) == 1
    assert filtered[0]["symbol"] == "RELIANCE"


# --- Dashboard tests -----------------------------------------------------------


def test_dashboard_returns_summary(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    resp = client.post(
        f"/api/tenants/{tenant.id}/paper-orders",
        json=_paper_order_payload(portfolio),
        headers=auth_header(token),
    )
    assert resp.status_code == 201

    resp = client.get(
        f"/api/tenants/{tenant.id}/dashboard/{portfolio.id}",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["portfolio_name"] == portfolio.name
    assert body["trading_mode"] == "PAPER"
    assert body["cash"] == 100000.0 - 10 * 100.0
    assert body["positions_count"] == 1
    assert body["risk_status"] == "NORMAL"


# --- Positions tests -----------------------------------------------------------


def test_positions_list_after_trades(client, db):
    tenant = create_test_tenant(db)
    _user, token = create_test_user(db, tenant)
    portfolio = _make_paper_portfolio(db, tenant)

    for symbol in ("RELIANCE", "TCS"):
        resp = client.post(
            f"/api/tenants/{tenant.id}/paper-orders",
            json=_paper_order_payload(portfolio, symbol=symbol),
            headers=auth_header(token),
        )
        assert resp.status_code == 201

    resp = client.get(
        f"/api/tenants/{tenant.id}/portfolios/{portfolio.id}/positions",
        headers=auth_header(token),
    )
    assert resp.status_code == 200
    positions = resp.json()
    assert len(positions) == 2
    assert {p["symbol"] for p in positions} == {"RELIANCE", "TCS"}


# --- Cross-tenant isolation -----------------------------------------------------


def test_paper_order_cross_tenant_denied(client, db):
    tenant_a = create_test_tenant(db)
    tenant_b = create_test_tenant(db)
    _user, token = create_test_user(db, tenant_a)
    portfolio = _make_paper_portfolio(db, tenant_b)

    resp = client.post(
        f"/api/tenants/{tenant_b.id}/paper-orders",
        json=_paper_order_payload(portfolio),
        headers=auth_header(token),
    )
    assert resp.status_code == 403
