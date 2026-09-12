"""End-to-end tests for the Phase 1 API endpoints.

Covers health, bootstrap, login, tenant/user/portfolio CRUD, the audit
trail, tenant isolation, and role enforcement.  All requests go through the
``/api`` prefix and use the shared fixtures from ``conftest.py``.
"""

from __future__ import annotations

import uuid


def _suffix() -> str:
    return uuid.uuid4().hex[:10]


def test_health_check(client):
    """GET /health returns 200 without authentication."""
    response = client.get("/health")
    assert (
        response.status_code == 200
    ), f"Expected 200 from /health, got {response.status_code}: {response.text}"


def test_bootstrap_token_works(client, admin_headers):
    """The bootstrapped platform admin token authorizes platform-admin endpoints."""
    response = client.get("/api/tenants", headers=admin_headers)
    assert (
        response.status_code == 200
    ), f"Bootstrapped admin token should list tenants, got {response.status_code}: {response.text}"
    assert isinstance(
        response.json(), list
    ), "Tenant list response should be a JSON array"


def test_bootstrap_duplicate_rejected(client, admin_headers):
    """Bootstrapping a second time returns 409 once the platform has users."""
    # admin_headers guarantees the platform is already bootstrapped.
    response = client.post(
        "/api/auth/bootstrap",
        json={
            "email": f"second-admin-{_suffix()}@example.com",
            "password": "another-pass-123",
        },
    )
    assert (
        response.status_code == 409
    ), f"Second bootstrap should return 409, got {response.status_code}: {response.text}"


def test_tenant_crud(client, admin_headers):
    """Platform admin can create, list, get, and update a tenant."""
    name = f"CRUD Tenant {_suffix()}"

    create_response = client.post(
        "/api/tenants", json={"name": name}, headers=admin_headers
    )
    assert (
        create_response.status_code == 201
    ), f"Create tenant failed: {create_response.text}"
    tenant = create_response.json()
    assert (
        tenant["name"] == name
    ), f"Created tenant name mismatch: {tenant['name']!r} != {name!r}"

    list_response = client.get("/api/tenants", headers=admin_headers)
    assert (
        list_response.status_code == 200
    ), f"List tenants failed: {list_response.text}"
    tenant_ids = [t["id"] for t in list_response.json()]
    assert tenant["id"] in tenant_ids, "Created tenant should appear in the tenant list"

    get_response = client.get(f"/api/tenants/{tenant['id']}", headers=admin_headers)
    assert get_response.status_code == 200, f"Get tenant failed: {get_response.text}"
    assert get_response.json()["name"] == name, "Get tenant returned the wrong tenant"

    updated_name = f"{name} (renamed)"
    update_response = client.patch(
        f"/api/tenants/{tenant['id']}",
        json={"name": updated_name, "subscription_plan": "PRO"},
        headers=admin_headers,
    )
    assert (
        update_response.status_code == 200
    ), f"Update tenant failed: {update_response.text}"
    updated = update_response.json()
    assert updated["name"] == updated_name, "Tenant name was not updated"
    assert (
        updated["subscription_plan"] == "PRO"
    ), "Tenant subscription plan was not updated"


def test_user_crud(client, admin_headers, tenant_with_admin):
    """Tenant admin can create users, list them, and update a user's role."""
    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]

    email = f"trader-{_suffix()}@example.com"
    create_response = client.post(
        f"/api/tenants/{tenant_id}/users",
        json={"email": email, "password": "trader-pass-123", "role": "TRADER"},
        headers=headers,
    )
    assert (
        create_response.status_code == 201
    ), f"Create user failed: {create_response.text}"
    user = create_response.json()
    assert user["email"] == email, "Created user email mismatch"
    assert user["role"] == "TRADER", "Created user role mismatch"

    list_response = client.get(f"/api/tenants/{tenant_id}/users", headers=headers)
    assert list_response.status_code == 200, f"List users failed: {list_response.text}"
    user_ids = [u["id"] for u in list_response.json()]
    assert user["id"] in user_ids, "Created user should appear in the tenant user list"
    assert (
        tenant_with_admin["user_id"] in user_ids
    ), "Tenant admin should appear in the user list"

    update_response = client.patch(
        f"/api/tenants/{tenant_id}/users/{user['id']}",
        json={"role": "RESEARCHER"},
        headers=headers,
    )
    assert (
        update_response.status_code == 200
    ), f"Update user role failed: {update_response.text}"
    assert update_response.json()["role"] == "RESEARCHER", "User role was not updated"


def test_login(client, tenant_with_admin):
    """Valid credentials return a token; invalid credentials return 401."""
    valid_response = client.post(
        "/api/auth/login",
        json={
            "email": tenant_with_admin["email"],
            "password": tenant_with_admin["password"],
        },
    )
    assert (
        valid_response.status_code == 200
    ), f"Valid login failed: {valid_response.text}"
    assert valid_response.json()[
        "access_token"
    ], "Login response should contain an access token"

    bad_password_response = client.post(
        "/api/auth/login",
        json={"email": tenant_with_admin["email"], "password": "wrong-password"},
    )
    assert (
        bad_password_response.status_code == 401
    ), f"Wrong password should return 401, got {bad_password_response.status_code}"

    unknown_email_response = client.post(
        "/api/auth/login",
        json={
            "email": f"nobody-{_suffix()}@example.com",
            "password": "whatever-pass-123",
        },
    )
    assert (
        unknown_email_response.status_code == 401
    ), f"Unknown email should return 401, got {unknown_email_response.status_code}"


def test_portfolio_crud(client, tenant_with_admin):
    """Tenant admin can create, list, get, update, and delete a portfolio."""
    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]
    base = f"/api/tenants/{tenant_id}/portfolios"

    create_response = client.post(
        base,
        json={"name": f"Growth Portfolio {_suffix()}", "starting_capital": 100000.0},
        headers=headers,
    )
    assert (
        create_response.status_code == 201
    ), f"Create portfolio failed: {create_response.text}"
    portfolio = create_response.json()
    assert (
        portfolio["current_equity"] == 100000.0
    ), "Current equity should equal starting capital"

    list_response = client.get(base, headers=headers)
    assert (
        list_response.status_code == 200
    ), f"List portfolios failed: {list_response.text}"
    portfolio_ids = [p["id"] for p in list_response.json()]
    assert (
        portfolio["id"] in portfolio_ids
    ), "Created portfolio should appear in the list"

    get_response = client.get(f"{base}/{portfolio['id']}", headers=headers)
    assert get_response.status_code == 200, f"Get portfolio failed: {get_response.text}"
    assert (
        get_response.json()["id"] == portfolio["id"]
    ), "Get portfolio returned the wrong record"

    update_response = client.patch(
        f"{base}/{portfolio['id']}",
        json={"name": "Growth Portfolio (v2)", "trading_mode": "LIVE"},
        headers=headers,
    )
    assert (
        update_response.status_code == 200
    ), f"Update portfolio failed: {update_response.text}"
    updated = update_response.json()
    assert updated["name"] == "Growth Portfolio (v2)", "Portfolio name was not updated"
    assert updated["trading_mode"] == "LIVE", "Portfolio trading mode was not updated"

    delete_response = client.delete(f"{base}/{portfolio['id']}", headers=headers)
    assert (
        delete_response.status_code == 204
    ), f"Delete portfolio failed: {delete_response.text}"

    gone_response = client.get(f"{base}/{portfolio['id']}", headers=headers)
    assert (
        gone_response.status_code == 404
    ), f"Deleted portfolio should return 404, got {gone_response.status_code}"


def test_audit_trail(client, tenant_with_admin):
    """Actions performed in a tenant are visible via the audit log endpoint."""
    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]

    # Perform an auditable action: create a portfolio.
    create_response = client.post(
        f"/api/tenants/{tenant_id}/portfolios",
        json={"name": f"Audit Portfolio {_suffix()}", "starting_capital": 5000.0},
        headers=headers,
    )
    assert (
        create_response.status_code == 201
    ), f"Create portfolio failed: {create_response.text}"

    audit_response = client.get(f"/api/tenants/{tenant_id}/audit", headers=headers)
    assert (
        audit_response.status_code == 200
    ), f"List audit events failed: {audit_response.text}"
    events = audit_response.json()
    assert events, "Audit log should contain events after tenant activity"

    actions = {event["action"] for event in events}
    assert (
        "portfolio_created" in actions
    ), f"Expected 'portfolio_created' in audit actions, got {actions}"
    assert (
        "user_login" in actions
    ), f"Expected 'user_login' in audit actions, got {actions}"
    assert all(
        event["tenant_id"] == tenant_id for event in events
    ), "All audit events for this endpoint should belong to the requested tenant"


def test_tenant_isolation(client, admin_headers, tenant_with_admin):
    """A tenant admin cannot read or write another tenant's resources (403)."""
    tenant_a_id = tenant_with_admin["tenant_id"]
    tenant_a_headers = tenant_with_admin["headers"]

    # Create a second tenant (with a user) via the platform admin.
    tenant_b_response = client.post(
        "/api/tenants",
        json={"name": f"Isolated Tenant {_suffix()}"},
        headers=admin_headers,
    )
    assert (
        tenant_b_response.status_code == 201
    ), f"Create second tenant failed: {tenant_b_response.text}"
    tenant_b_id = tenant_b_response.json()["id"]

    users_response = client.get(
        f"/api/tenants/{tenant_b_id}/users", headers=tenant_a_headers
    )
    assert (
        users_response.status_code == 403
    ), f"Cross-tenant user list should return 403, got {users_response.status_code}"

    portfolios_response = client.get(
        f"/api/tenants/{tenant_b_id}/portfolios", headers=tenant_a_headers
    )
    assert (
        portfolios_response.status_code == 403
    ), f"Cross-tenant portfolio list should return 403, got {portfolios_response.status_code}"

    create_response = client.post(
        f"/api/tenants/{tenant_b_id}/portfolios",
        json={"name": "Intruder Portfolio", "starting_capital": 1.0},
        headers=tenant_a_headers,
    )
    assert (
        create_response.status_code == 403
    ), f"Cross-tenant portfolio create should return 403, got {create_response.status_code}"

    audit_response = client.get(
        f"/api/tenants/{tenant_b_id}/audit", headers=tenant_a_headers
    )
    assert (
        audit_response.status_code == 403
    ), f"Cross-tenant audit read should return 403, got {audit_response.status_code}"

    # Sanity check: the same admin can still access its own tenant.
    own_response = client.get(
        f"/api/tenants/{tenant_a_id}/portfolios", headers=tenant_a_headers
    )
    assert (
        own_response.status_code == 200
    ), f"Own-tenant access failed: {own_response.text}"


def test_role_enforcement(client, tenant_with_admin):
    """A VIEWER can read but cannot create or modify resources (403)."""
    tenant_id = tenant_with_admin["tenant_id"]
    headers = tenant_with_admin["headers"]

    viewer_email = f"viewer-{_suffix()}@example.com"
    viewer_password = "viewer-pass-123"
    create_response = client.post(
        f"/api/tenants/{tenant_id}/users",
        json={"email": viewer_email, "password": viewer_password, "role": "VIEWER"},
        headers=headers,
    )
    assert (
        create_response.status_code == 201
    ), f"Create viewer failed: {create_response.text}"

    login_response = client.post(
        "/api/auth/login",
        json={"email": viewer_email, "password": viewer_password},
    )
    assert (
        login_response.status_code == 200
    ), f"Viewer login failed: {login_response.text}"
    viewer_headers = {
        "Authorization": f"Bearer {login_response.json()['access_token']}"
    }

    read_response = client.get(
        f"/api/tenants/{tenant_id}/portfolios", headers=viewer_headers
    )
    assert (
        read_response.status_code == 200
    ), f"Viewer should be able to read portfolios: {read_response.text}"

    create_portfolio_response = client.post(
        f"/api/tenants/{tenant_id}/portfolios",
        json={"name": "Viewer Portfolio", "starting_capital": 100.0},
        headers=viewer_headers,
    )
    assert (
        create_portfolio_response.status_code == 403
    ), f"Viewer creating a portfolio should return 403, got {create_portfolio_response.status_code}"

    create_user_response = client.post(
        f"/api/tenants/{tenant_id}/users",
        json={
            "email": f"viewer-spawn-{_suffix()}@example.com",
            "password": "spawn-pass-123",
            "role": "VIEWER",
        },
        headers=viewer_headers,
    )
    assert (
        create_user_response.status_code == 403
    ), f"Viewer creating a user should return 403, got {create_user_response.status_code}"
