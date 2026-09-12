## Implementation Report

### Files created
- **`services/api-gateway/app/routers/ohlcv.py`** (89 lines) — created with the exact content specified in the task.

### Summary of changes
Created the OHLCV router module containing:
1. **`POST /instruments/{instrument_id}/ohlcv`** (`upload_ohlcv`) — batch upsert of OHLCV bars using PostgreSQL `INSERT ... ON CONFLICT DO UPDATE` on the `uq_ohlcv_bar` constraint; restricted to `PLATFORM_ADMIN` via `require_role`; returns `{"upserted": N}`; returns 404 if the instrument doesn't exist and `{"upserted": 0}` for an empty batch.
2. **`GET /instruments/{instrument_id}/ohlcv`** (`query_ohlcv`) — queries bars filtered by `timeframe` (default `"1d"`), optional `start`/`end` datetime range, and `limit` (default 500, max 5000), ordered by timestamp ascending; any authenticated user; returns 404 if the instrument doesn't exist.

No extra endpoints, imports, or code were added beyond the specification.

### Commands run and output
1. `ls services/api-gateway/app/routers/ services/api-gateway/app/` — confirmed target directory exists with sibling routers (`audit.py`, `auth.py`, `instruments.py`, etc.) and that `app/models.py`, `app/schemas.py`, `app/auth.py`, `app/database.py` exist.
2. `write` tool (twice — the tool-call echo appeared garbled, but verification showed the on-disk content was correct from the first write; second write produced identical content).
3. `read` of the written file — confirmed the full 89-line content matches the specification exactly.
4. `diff /tmp/expected_ohlcv.py services/api-gateway/app/routers/ohlcv.py` → **DIFF: IDENTICAL** (md5 `860cb572df91d104f9a40d2aff39daf6` for both); temp file removed afterward.
5. `python3 -m py_compile services/api-gateway/app/routers/ohlcv.py` → **COMPILE: OK** (no syntax errors).
6. `grep` for critical lines — confirmed all key statements present at expected line numbers (upsert at lines 50–62, timestamp filters at 85–89).
7. `grep` in `app/models.py`, `app/schemas.py`, `app/auth.py`, `app/database.py` — verified every imported symbol exists: `User` (models.py:51), `Instrument` (:97), `OHLCVBar` (:113), `OHLCVBarCreate` (schemas.py:149), `OHLCVBarResponse` (:159), `get_current_user` (auth.py:46), `require_role` (auth.py:68), `get_db` (database.py:19).

### Issues, risks, deviations
- **No deviations** — the file content is byte-for-byte identical to the requested content (verified by md5 checksum and diff).
- **Observation (not a defect in this task):** during writing, the tool-call echo displayed garbled text; I verified via independent reads, diff, and checksums that the file on disk was never actually corrupted.
- **Note for integration:** this router is not yet registered/included in the FastAPI application (`main.py` or equivalent) — that was outside the scope of this task. Also, the upsert depends on a database unique constraint named `uq_ohlcv_bar` existing on the `OHLCVBar` table; that is defined outside this file (migrations/models) and was not part of this task.
