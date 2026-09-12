## Implementation Report

### Files created
1. **`/home/udai/personal/aegis/services/api-gateway/app/routers/portfolios.py`**
   - Created with the exact content specified in the task. Implements tenant-scoped portfolio CRUD endpoints: `list_portfolios` (GET), `create_portfolio` (POST, 201), `get_portfolio` (GET /{portfolio_id}), `update_portfolio` (PATCH), `delete_portfolio` (DELETE, 204). Uses `_check_tenant_access` helper for tenant isolation (non-platform admins restricted to their own tenant), `require_role` for RBAC, and `record_audit` to log `portfolio_created`, `portfolio_updated`, and `portfolio_deleted` events.

2. **`/home/udai/personal/aegis/services/api-gateway/app/routers/audit.py`**
   - Created with the exact content specified in the task. Implements `list_audit_events` (GET) under the `/tenants/{tenant_id}/audit` prefix with `limit` (1–500, default 50) and `offset` (default 0) pagination, restricted to `PLATFORM_ADMIN` and `TENANT_ADMIN` roles, with tenant-access enforcement (403 for cross-tenant access by non-platform admins).

### Commands run and output
- `cd /home/udai/personal/aegis/services/api-gateway && python -m py_compile app/routers/portfolios.py app/routers/audit.py && echo OK`
  - Output: `OK` — both files are syntactically valid Python.

### Issues, risks, or deviations
- None. Both files were written byte-for-byte as specified. No other files were created, modified, or deleted. No tests, docs, or git operations were performed.
- Note (informational only, no action taken): the routers are not yet registered in the app (e.g., via `include_router` in `app/main.py`); the task did not request that, so it was not done.
