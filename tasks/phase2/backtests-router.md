## Implementation Report

### Files created
- **`services/api-gateway/app/routers/backtests.py`** — New router file created with the exact content specified in the task. It implements tenant-scoped backtest run CRUD endpoints:
  - `_check_tenant_access` helper (403 for non-platform-admins outside the tenant)
  - `GET /tenants/{tenant_id}/backtests` — list with optional `portfolio_id` and `status` filters, pagination, ordered by `created_at` desc
  - `POST /tenants/{tenant_id}/backtests` — create with portfolio/strategy-config tenant validation, date-range validation, audit recording (`backtest_created`), returns 201
  - `GET /tenants/{tenant_id}/backtests/{backtest_id}` — fetch single run, 404 if not found in tenant

  The content was written exactly as provided — no extra endpoints, imports, or code were added or removed.

### Commands run and output
```
$ python3 -m py_compile services/api-gateway/app/routers/backtests.py && echo "SYNTAX OK"
SYNTAX OK

$ grep -n "class BacktestRun\b\|class StrategyConfig\b" services/api-gateway/app/models.py
147:class StrategyConfig(Base):
161:class BacktestRun(Base):

$ grep -n "class BacktestRunCreate\|class BacktestRunResponse" services/api-gateway/app/schemas.py
236:class BacktestRunCreate(BaseModel):
245:class BacktestRunResponse(BaseModel):
```

### Verification
- File compiles cleanly (`py_compile` passed).
- All referenced symbols exist: `BacktestRun`, `Portfolio` (existing), `StrategyConfig` in `app/models.py`; `BacktestRunCreate` and `BacktestRunResponse` in `app/schemas.py`. The pattern (tenant check, `require_role`, `record_audit`) matches the existing `portfolios.py`/`users.py` conventions.

### Issues / risks / deviations
- No deviations from the requested content.
- One integration note (no action taken, out of scope): the new router must be registered (e.g., `app.include_router(backtests.router)`) in the FastAPI app entrypoint for the endpoints to be live — the task did not request modifying any other file, so I left registration untouched.
