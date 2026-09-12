I have completed the task. Below is the full implementation report.

## 1. Files created, modified, or deleted

- **Created:** `services/api-gateway/app/routers/instruments.py` (78 lines)
- **Modified:** none
- **Deleted:** none

## 2. Summary of each change and why

**`services/api-gateway/app/routers/instruments.py` — created.**
Wrote the file exactly as specified in the request, with no added endpoints, imports, or code. Contents:

- Module docstring `"""Instrument management endpoints."""`, `from __future__ import annotations`, `import uuid`.
- Imports from `fastapi`, `sqlalchemy.orm`, and the existing app modules `app.auth`, `app.audit`, `app.database`, `app.models`, `app.schemas`.
- `router = APIRouter(prefix="/instruments", tags=["instruments"])`.
- `GET /instruments` (`list_instruments`): returns active instruments ordered by `symbol`; depends on `get_db` and `get_current_user` (any authenticated user).
- `POST /instruments` (`create_instrument`): platform-admin only via `require_role("PLATFORM_ADMIN")`; checks for an existing `(symbol, exchange)` pair and raises `409 CONFLICT`; constructs the `Instrument` from the request body, `db.add` + `db.flush`, records an audit event with `record_audit(...)`, commits, refreshes, and returns the row.
- `GET /instruments/{instrument_id}` (`get_instrument`): fetches by UUID, raises `404 NOT_FOUND` if absent; any authenticated user.

This matches the exact import style, error handling, audit pattern, and response pattern used by the existing `tenants.py` and `users.py` routers, and it relies only on symbols that already exist in the codebase (`Instrument` in `app/models.py`; `InstrumentCreate`/`InstrumentResponse` in `app/schemas.py`; `get_current_user`/`require_role` in `app/auth.py`; `record_audit` in `app/audit.py`).

## 3. Commands and output

- **Verification of existing patterns/symbols** — read `tenants.py`, `users.py`, `schemas.py`, `models.py`, `auth.py`, `audit.py`, and `main.py` to confirm the referenced imports, models, schemas, and function signatures all exist. All exist and are compatible.
- **Syntax check / lint:**
  ```
  cd /home/udai/personal/aegis/services/api-gateway && python -m py_compile app/routers/instruments.py && ruff check app/routers/instruments.py
  ```
  Output:
  ```
  py_compile OK
  All checks passed!
  ```
  (stderr noted `landlock-run: partial enforcement (older Landlock ABI)` — a sandbox informational message, not an error; exit code 0.)
- **Read-back** of the created file confirmed it is byte-for-byte the requested content.

## 4. Issues, risks, or deviations

- **No deviations from the requested file content.** The file was written exactly as specified, including the compact single-line list query and the lack of a blank line between the docstring and `from __future__ import annotations`.
- **Router is not registered (out of scope, flagged not changed):** `services/api-gateway/main.py` currently imports and mounts `auth, tenants, users, portfolios, audit` only (lines 10, 30–34). Because the instructions explicitly said not to add any code beyond the specified file, I did **not** modify `main.py`. As a result, the new `/api/instruments` endpoints will not be reachable at runtime until `instruments` is added to that import and an `app.include_router(instruments.router, prefix="/api")` line is added. Worth doing in a follow-up if the endpoints are expected to be live.
- **No runtime/DB test executed:** there is no test suite invocation in this task, and the endpoints weren't exercised against a database. Validation is limited to import-symbol verification, `py_compile`, and `ruff`. The `Instrument` model has a `(symbol, exchange)` unique constraint, so the application-level duplicate check is backed by a DB guarantee (a concurrent insert could still surface an `IntegrityError` rather than the `409`, which is the same behavior as the existing routers).
- **Related note (not changed):** `services/api-gateway/app/routers/__init__.py` is empty, so the `from app.routers import auth, tenants, ...` style in `main.py` works via implicit submodule import; no package `__init__` change is needed for a future registration of `instruments`.
