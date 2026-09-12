"""Test fixtures: SQLite in-memory database, test client, and helper factories."""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth import create_access_token, hash_password
from app.database import Base, get_db
from app.models import Portfolio, Tenant, User
from main import app

TEST_DB_URL = "sqlite://"  # in-memory

# StaticPool keeps a single shared connection so the in-memory database
# persists across commits/connections for the duration of a test run.
engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)


# SQLite doesn't support UUID natively; enable foreign keys like the app expects.
@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_conn, connection_record):
    dbapi_conn.execute("PRAGMA foreign_keys=ON")


TestSession = sessionmaker(bind=engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestSession()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def admin_headers(client) -> dict:
    """Bootstrap a platform admin and return its Authorization header."""
    response = client.post(
        "/api/auth/bootstrap",
        json={
            "email": f"admin-{uuid.uuid4().hex[:8]}@test.com",
            "password": "admin-pass-123",
        },
    )
    assert response.status_code == 201, f"Bootstrap failed: {response.text}"
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def tenant_with_admin(client, admin_headers) -> dict:
    """Create a tenant with a TENANT_ADMIN user and return its login state."""
    tenant_response = client.post(
        "/api/tenants",
        json={"name": f"test-tenant-{uuid.uuid4().hex[:8]}"},
        headers=admin_headers,
    )
    assert (
        tenant_response.status_code == 201
    ), f"Create tenant failed: {tenant_response.text}"
    tenant_id = tenant_response.json()["id"]

    email = f"tenant-admin-{uuid.uuid4().hex[:8]}@test.com"
    password = "tenant-pass-123"
    user_response = client.post(
        f"/api/tenants/{tenant_id}/users",
        json={"email": email, "password": password, "role": "TENANT_ADMIN"},
        headers=admin_headers,
    )
    assert (
        user_response.status_code == 201
    ), f"Create tenant admin failed: {user_response.text}"
    user_id = user_response.json()["id"]

    login_response = client.post(
        "/api/auth/login", json={"email": email, "password": password}
    )
    assert (
        login_response.status_code == 200
    ), f"Tenant admin login failed: {login_response.text}"
    token = login_response.json()["access_token"]

    return {
        "tenant_id": tenant_id,
        "user_id": user_id,
        "email": email,
        "password": password,
        "headers": {"Authorization": f"Bearer {token}"},
    }


def create_test_tenant(db) -> Tenant:
    tenant = Tenant(name=f"test-tenant-{uuid.uuid4().hex[:8]}", status="ACTIVE")
    db.add(tenant)
    db.flush()
    return tenant


def create_test_user(db, tenant, role="RESEARCHER") -> tuple[User, str]:
    user = User(
        tenant_id=tenant.id,
        email=f"user-{uuid.uuid4().hex[:8]}@test.com",
        password_hash=hash_password("testpass123"),
        role=role,
    )
    db.add(user)
    db.flush()
    token = create_access_token(user.id, tenant.id, role)
    return user, token


def create_platform_admin(db) -> tuple[User, str]:
    admin = User(
        email=f"admin-{uuid.uuid4().hex[:8]}@test.com",
        password_hash=hash_password("testpass123"),
        role="PLATFORM_ADMIN",
        tenant_id=None,
    )
    db.add(admin)
    db.flush()
    token = create_access_token(admin.id, None, "PLATFORM_ADMIN")
    return admin, token


def create_test_portfolio(db, tenant, capital=100000.0) -> Portfolio:
    portfolio = Portfolio(
        tenant_id=tenant.id,
        name=f"test-portfolio-{uuid.uuid4().hex[:8]}",
        starting_capital=capital,
        current_equity=capital,
        cash=capital,
        trading_mode="BACKTEST",
    )
    db.add(portfolio)
    db.flush()
    return portfolio


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
