## Report

### Files modified
1. **services/api-gateway/app/routers/strategies.py** — In `update_strategy`, added a null-check loop after `updates = body.model_dump(exclude_unset=True)` and before the `setattr` loop, matching the existing pattern in `strategy_configs.py`'s `update_strategy_config`. For each of `"name"`, `"version"`, and `"status"`, if present in `updates` with a `None` value, it raises `HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"{key} cannot be set to null")`.
2. **services/api-gateway/app/schemas.py** — In `OHLCVBarCreate`, added `Field(allow_inf_nan=False)` to `open`, `high`, `low`, and `close` to reject NaN/Inf values. The initially ambiguous edit (same pattern existed in `OHLCVBarResponse`) was resolved by including class context; only the `Create` model was modified.

### Commands run and output
- `grep -n "update_strategy_config" -A 40 ...strategy_configs.py` — inspected the reference null-check pattern.
- `grep -n -B 4 -A 1 "open: float" schemas.py` — located duplicate `open/high/low/close` blocks to disambiguate the edit.
- `python -m py_compile app/routers/strategies.py` → `syntax ok`
- Isolated Pydantic validation test on `schemas.py`:
  - finite values → accepted (`ok`)
  - `open=NaN` → rejected with `ValidationError`
  - `open=Inf` → rejected with `ValidationError`

### Issues / risks / deviations
- Full import of the `strategies` router fails with a pre-existing environment issue: `app/models.py` raises a `TypeError` under SQLAlchemy + Python 3.14 (Anaconda Python) when defining the `Tenant` model. This is unrelated to my change; the router module was syntax-checked with `py_compile` instead.
- The working tree has uncommitted changes in other files (`audit.py`, `auth.py`, `models.py`, etc.) that pre-date my edits; I only touched the two requested files.
