# Implementation Report — Phase 2 API Tests

## 1. Files created / modified / deleted

| File | Action | Purpose |
|---|---|---|
| `services/api-gateway/tests/test_phase2_api.py` | **Created** | 21 pytest tests covering all Phase 2 endpoints (instruments, OHLCV, strategies, strategy configs, backtests) |

No existing files were modified or deleted. The temp verification venv (`/tmp/aegis-venv*`) was removed after the runs.

## 2. Summary of the change

The new file follows the conventions of `tests/test_phase1_api.py` and `conftest.py` (uuid suffixes, descriptive assert messages, `/api` prefix, shared `client` / `admin_headers` / `tenant_with_admin` fixtures). It contains:

- **Module-level helpers** to chain setup: `_create_instrument`, `_create_researcher` (creates a RESEARCHER user via `/api/tenants/{id}/users` then logs in), `_create_portfolio`, `_create_strategy_config`, `_create_backtest`.
- **Instrument tests (5):** create → 201 with field checks; list shows active instruments; get by ID (plus 404 for unknown); duplicate symbol+exchange → 409; TENANT_ADMIN create → 403.
- **OHLCV tests (4):** batch upload returns `{"upserted": N}`; re-upload of same timestamp updates the bar (1 bar remains, values updated) rather than duplicating; timeframe filter returns only matching bars; `start`/`end` date-range filter returns only in-range timestamps.
- **Strategy tests (4):** platform admin creates PLATFORM strategy (`tenant_id` is None); RESEARCHER creates TENANT strategy scoped to their tenant; visibility list for a researcher includes platform + own-tenant strategies but excludes a second tenant's strategy (second tenant created inline with admin_headers); platform admin PATCH updates `version` and `description`.
- **Strategy config tests (4):** create linking tenant strategy + tenant portfolio with parameters/lifecycle_status; PATCH updates `parameters` and `lifecycle_status`; DELETE → 204 then GET → 404; cross-tenant validation — foreign portfolio rejected (404) and foreign tenant strategy rejected (403) when another tenant's admin attempts to use them.
- **Backtest tests (4):** RESEARCHER creates a run, status is `PENDING` and `metrics` is None; `start_date >= end_date` returns 400 (both equal and reversed dates tested); list + filters (`portfolio_id`, `status=PENDING`) + single GET + 404 for unknown; tenant isolation — a foreign tenant's RESEARCHER gets 403 on list, get, and create against the first tenant's backtests.

## 3. Commands run and output

- `python -m pytest tests/test_phase2_api.py` (system anaconda Python 3.14) — **failed at import** with `TypeError: descriptor '__getitem__' requires a 'typing.Union' object`. Reproduced identically with `tests/test_phase1_api.py`, so it's a pre-existing environment issue (pinned `sqlalchemy==2.0.35` is incompatible with Python 3.14), not caused by my tests.
- The system `localhost:5432` Postgres rejected `aegis:aegis` / `aegis:aegis_local_dev`. Discovered the `aegis-postgres` Docker container (postgres:18-alpine, credentials `aegis_local_dev` from `.env.local`) is running with its port **not published** to the host, so tests must target the container's bridge IP.
- Created an isolated Python 3.12 venv with `requirements.txt` + `requirements-test.txt` and ran:
  - `DATABASE_URL='postgresql://aegis:aegis_local_dev@172.20.0.2:5432/aegis' pytest tests/test_phase2_api.py -v` → **21 passed in ~12s**
  - `DATABASE_URL=... pytest tests/ -q` (full suite, Phase 1 + Phase 2 together) → **31 passed in ~17.6s** — no cross-file interference
  - `ruff check tests/test_phase2_api.py` → after removing one unused `date` import: **All checks passed!**

## 4. Issues, risks, and deviations

- **Pre-existing environment issues (not caused by this task, not fixed here per surgical-change policy):**
  1. `sqlalchemy==2.0.35` (pinned in `requirements.txt`) is incompatible with Python 3.14 (the default system interpreter) — the entire test suite fails at import on it. Verified in a Python 3.12 venv that everything works; CI presumably uses an appropriate Python.
  2. `conftest.py`'s default `DATABASE_URL` (`postgresql://aegis:aegis@localhost:5432/aegis`) does not match the local Docker Postgres credentials (`aegis_local_dev`), and `docker-compose.yml` does not publish port 5432 to the host, so the test DB is only reachable via the container's bridge-network IP. Tests were verified with `DATABASE_URL` pointing at the container.
- **Test-design notes:**
  - `test_instrument_get` additionally covers the 404 path for an unknown instrument; `test_backtest_list_and_get` covers the 404 path there too (kept in-test since each is a single extra request).
  - Cross-tenant strategy-config validation distinguishes the two failure modes: foreign portfolio → 404 ("not found in this tenant") and foreign tenant strategy → 403, matching the router's actual semantics.
  - Strategy-config delete requires TENANT_ADMIN/PLATFORM_ADMIN (not RESEARCHER), so those tests use `tenant_with_admin["headers"]`.
