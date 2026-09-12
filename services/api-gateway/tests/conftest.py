"""Shared pytest fixtures for the api-gateway test suite.

The suite runs against a real PostgreSQL database (never the live one): the
``DATABASE_URL`` environment variable is read *before* the application is
imported so that ``app.database`` binds its engine to the test database.  The
schema is dropped and recreated once per test session; each test function gets
its own session while the tables (and committed rows) persist for the whole
session.

Typical usage::

    def test_health(client):
        assert client.get("/api/tenants").status_code == 401
"""

from __future__ import annotations

import os
import sys
import uuid
from collections.abc import Generator
from pathlib import Path

# ``conftest.py`` lives at ``<service>/tests/conftest.py`` but the application
# is imported as the top-level ``app`` package.  Make the service root
# importable so the suite works no matter where pytest is invoked from.
SERVICE_ROOT = Path(__file__).resolve().parent.parent
if str(SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(SERVICE_ROOT))

# Must be set before importing anything from ``app``.
os.environ.setdefault(
    "DATABASE_URL", "postgresql://aegis:aegis@localhost:5432/aegis_test"
)
os.environ.setdefault("JWT_SECRET", "test-jwt-secret")

import httpx  # noqa: E402
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402

from app.auth import create_access_token  # noqa: E402
from app.config import settings  # noqa: E402
from app.database import Base, get_db  # noqa: E402
from main import app  # noqa: E402

# Dedicated credentials for the platform admin bootstrapped by ``admin_token``.
ADMIN_EMAIL = "admin@example.com"
ADMIN_PASSWORD = "admin-test-pass"


@pytest.fixture(scope="session")
def engine():
    """SQLAlchemy engine bound to the test database."""
    engine = create_engine(settings.database_url, pool_pre_ping=True)
    try:
        yield engine
    finally:
        engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def _reset_database(engine):
    """Drop and recreate every table once, giving the suite a clean slate."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    # Best-effort cleanup; failures here must not fail the suite.
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:  # pragma: no cover - defensive teardown
        pass


@pytest.fixture
def db_session(engine) -> Generator[Session, None, None]:
    """A fresh ORM session for tests that need to inspect or seed the DB.

    The session is intentionally *not* closed by the request override below, so
    callers may keep using it after an API call; this fixture owns its lifetime.
    """
    session = sessionmaker(bind=engine, autoflush=False)()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(engine) -> Generator[httpx.Client, None, None]:
    """A synchronous httpx client wired to the FastAPI app.

    ``TestClient`` is an ``httpx.Client`` subclass, so tests get the usual httpx
    API.  ``get_db`` is overridden to hand every request a session bound to the
    test engine instead of the application's configured database.
    """

    def override_get_db() -> Generator[Session, None, None]:
        db = sessionmaker(bind=engine, autoflush=False)()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    # The session fixture prepares the schema; entering the client also runs the
    # app lifespan (whose ``create_all`` is idempotent).
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _ensure_platform_admin(engine) -> str:
    """Return a platform-admin JWT, creating the admin on first use.

    Prefers the real ``/api/auth/bootstrap`` endpoint so callers exercise the
    bootstrap flow.  On later calls, when the platform is already bootstrapped,
    the existing admin is looked up and a token is minted directly.
    """
    from app.models import User

    session_factory = sessionmaker(bind=engine, autoflush=False)
    with TestClient(app) as api:
        response = api.post(
            "/api/auth/bootstrap",
            json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        )
        if response.status_code == 201:
            return response.json()["access_token"]

    assert response.status_code == 409, response.text
    with session_factory() as db:
        admin = db.query(User).filter_by(email=ADMIN_EMAIL).one()
        return create_access_token(admin.id, admin.tenant_id, admin.role)


@pytest.fixture(scope="session")
def admin_token(engine) -> str:
    """JWT for a bootstrapped platform admin (created once per session)."""
    return _ensure_platform_admin(engine)


@pytest.fixture
def admin_headers(admin_token) -> dict[str, str]:
    """Authorization header for the bootstrapped platform admin."""
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def tenant_with_admin(client, admin_headers) -> dict:
    """Create a tenant plus its first TENANT_ADMIN and return auth details."""
    suffix = uuid.uuid4().hex[:10]
    tenant_name = f"Test Tenant {suffix}"
    admin_email = f"tenant-admin-{suffix}@example.com"
    admin_password = "tenant-admin-pass"

    tenant_response = client.post(
        "/api/tenants",
        json={"name": tenant_name},
        headers=admin_headers,
    )
    assert tenant_response.status_code == 201, tenant_response.text
    tenant = tenant_response.json()

    user_response = client.post(
        f"/api/tenants/{tenant['id']}/users",
        json={"email": admin_email, "password": admin_password, "role": "TENANT_ADMIN"},
        headers=admin_headers,
    )
    assert user_response.status_code == 201, user_response.text
    user = user_response.json()

    login_response = client.post(
        "/api/auth/login",
        json={"email": admin_email, "password": admin_password},
    )
    assert login_response.status_code == 200, login_response.text
    token = login_response.json()["access_token"]

    return {
        "tenant_id": tenant["id"],
        "tenant": tenant,
        "user_id": user["id"],
        "user": user,
        "email": admin_email,
        "password": admin_password,
        "token": token,
        "headers": {"Authorization": f"Bearer {token}"},
    }
