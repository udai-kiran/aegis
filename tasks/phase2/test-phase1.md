# Implementation Report

## Files created

- **`services/api-gateway/tests/test_phase1_api.py`** — new pytest suite covering all 10 requested Phase 1 API flows. No existing files were modified or deleted.

## Summary of the test file

Follows the conventions of `conftest.py` (module docstring, `from __future__ import annotations`, `uuid`-suffixed names/emails for uniqueness, shared fixtures). One test function per requested flow:

| Test | Coverage |
|---|---|
| `test_health_check` | `GET /health` → 200, unauthenticated |
| `test_bootstrap_token_works` | Uses `admin_headers` (which bootstraps via the real endpoint) to hit a PLATFORM_ADMIN endpoint (`GET /api/tenants`) → 200 |
| `test_bootstrap_duplicate_rejected` | Second `POST /api/auth/bootstrap` → 409 |
| `test_tenant_crud` | Create (201) → list (contains new tenant) → get → patch name + subscription_plan, verifying response fields |
| `test_user_crud` | Via `tenant_with_admin`: create TRADER user → list contains both users → patch role to RESEARCHER |
| `test_login` | Valid creds → 200 + token; wrong password → 401; unknown email → 401 |
| `test_portfolio_crud` | Create (201, equity == starting capital) → list → get → patch name/trading_mode → delete (204) → get → 404 |
| `test_audit_trail` | After portfolio creation, `GET /api/tenants/{id}/audit` contains `portfolio_created` and `user_login` actions, all rows scoped to the tenant |
| `test_tenant_isolation` | Tenant A admin vs. tenant B: users/portfolios/audit reads and portfolio create all → 403; own-tenant access still 200 |
| `test_role_enforcement` | VIEWER user can list portfolios (200) but cannot create portfolios or users (403) |

All requests use the `/api/` prefix and every assertion carries a descriptive failure message.

## Commands run and output

1. `python -m pytest tests/test_phase1_api.py` with the system Anaconda Python 3.14 — **collection error before any test ran**: SQLAlchemy 2.0.35 (pinned in `requirements.txt`) is incompatible with Python 3.14's `typing.Union` (`TypeError: descriptor '__getitem__' requires a 'typing.Union' object`). Pre-existing environment issue, unrelated to the test file.
2. Created a clean venv with `python3.12` and installed `requirements.txt` + `requirements-test.txt` — succeeded.
3. First run in the venv failed with `psycopg2.OperationalError`: `localhost:5432` is occupied by a different project's postgres (`anvil-postgres`); the `aegis-postgres` container is running but its port is not published.
4. Pointed `DATABASE_URL` at the aegis container directly (credentials from `docker inspect aegis-postgres`): `DATABASE_URL="postgresql://aegis:aegis_local_dev@172.19.0.3:5432/aegis"` —
   **`10 passed in 5.72s`**.
5. `ruff check tests/test_phase1_api.py` — **All checks passed!**

## Issues, risks, deviations

- **Environment only, no code deviation**: the default `DATABASE_URL` in `conftest.py` (`localhost:5432`) does not resolve to the aegis database on this machine because another project's postgres holds that port; tests were verified against the aegis container via its Docker network IP. On a normal dev setup (port published per `docker-compose.dev.yml`) the default URL works unchanged.
- `admin_headers` is function-scoped while `admin_token` is session-scoped; the suite assumes bootstrap persists across the session (as designed in `conftest.py`), which `test_bootstrap_duplicate_rejected` relies on.
- The session-scoped `_reset_database` drops all tables in the target DB at teardown — running the suite requires a disposable database, which the aegis dev container is.
