## Report

### Files modified
1. **services/api-gateway/app/routers/strategy_configs.py**
   - **Change (a) — delete FK handling:** Added `from sqlalchemy.exc import IntegrityError` to the imports. In `delete_strategy_config`, wrapped `db.delete(config)` + `db.commit()` in a `try/except IntegrityError`; on catch, it calls `db.rollback()` and raises `HTTPException(status.HTTP_409_CONFLICT, detail="Cannot delete: strategy config has dependent resources (e.g., backtest runs)")`.
   - **Change (b) — null patch rejection:** In `update_strategy_config`, immediately after `updates = body.model_dump(exclude_unset=True)`, added a validation loop: if any of `"parameters"`, `"lifecycle_status"`, or `"is_active"` is present in `updates` with a `None` value, it raises `HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"{key} cannot be set to null")` before any attribute mutation or flush occurs.
2. **services/api-gateway/app/routers/portfolios.py**
   - Added `from sqlalchemy.exc import IntegrityError` to the imports. In `delete_portfolio`, wrapped `db.delete(portfolio)` + `db.commit()` in a `try/except IntegrityError`; on catch, `db.rollback()` and raise `HTTPException(status.HTTP_409_CONFLICT, detail="Cannot delete: portfolio has dependent resources")`.

### Why
- Deleting a strategy config / portfolio with dependent rows (e.g., backtest runs referencing them) previously surfaced as an unhandled `IntegrityError` → 500. Now it's a clean 409 with an explanatory detail, and the session is rolled back.
- PATCHing a strategy config with explicit `null` for non-nullable fields would crash at flush; now rejected up front with a 400 naming the offending key.

### Commands run
- `python -c "import ast; ast.parse(...); ..."` for both files → output: `syntax OK`
- `git diff --stat` and `git status --short services/api-gateway/app/routers/` to confirm only the two target files were touched by me. Note: `portfolios.py` shows a larger diff in the working tree because other uncommitted changes pre-existed; `strategy_configs.py` is untracked (pre-existing new file, not created by me). My edits were limited to the imports and the two endpoints described above.

### Issues / deviations
- None. No other files were touched. Validation uses `key in updates and updates[key] is None` (rather than iterating all values) so only the three named fields are checked, per spec; other nullable-optional fields in the schema are unaffected. The 400 check occurs before the audit `before`-state mutation loop, so a rejected request leaves the ORM object untouched.
