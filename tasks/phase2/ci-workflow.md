## Implementation Report

### Files created
1. **`.github/workflows/ci.yml`** — new GitHub Actions CI/CD workflow for the Aegis Trader monorepo.

### Summary of changes
The workflow triggers on push to `main` and PRs to `main`, and defines the 3 requested jobs:

- **`lint`** — checks out code, sets up Python 3.12 with pip caching (`actions/setup-python@v5` `cache: pip`), installs `ruff`, then runs `ruff check services/api-gateway/` and `ruff format --check services/api-gateway/`.
- **`test`** — runs on `ubuntu-latest` with a `postgres:18-alpine` service container (`POSTGRES_DB: aegis_test`, `POSTGRES_USER: aegis`, `POSTGRES_PASSWORD: testpass`, health check via `pg_isready`, port 5432 mapped to localhost). Job-level env sets `DATABASE_URL=postgresql://aegis:testpass@localhost:5432/aegis_test` and `JWT_SECRET=test-jwt-secret`. Installs `requirements.txt` + `requirements-test.txt` from `services/api-gateway/`, then runs `pytest services/api-gateway/tests/ -v`.
- **`build`** — `needs: [lint, test]`. Top-level `permissions: contents: read` on the workflow; the build job overrides with `contents: read, packages: write`. Uses `docker/setup-buildx-action@v3`, `docker/login-action@v3` (ghcr.io, `github.actor` + `secrets.GITHUB_TOKEN`) gated behind `if: github.event_name == 'push'`, and `docker/build-push-action@v6` with `push: ${{ github.event_name == 'push' }}` — so PRs build without pushing, and main pushes. Tags come from `docker/metadata-action@v5`: `type=sha` (SHA tag) plus `type=raw,value=latest,enable={{is_default_branch}}` (latest only on main). Image: `ghcr.io/${{ github.repository }}/api-gateway`. GHA build cache (`cache-from/cache-to: type=gha`) is enabled for faster builds.

I read the existing `Makefile` and `docker-compose.yml` for context — the compose file confirmed `postgres:18-alpine`, the `DATABASE_URL` format, and `JWT_SECRET` conventions used in the workflow.

### Commands run and output
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` → `YAML OK` (validates acceptance criterion 1).

### Issues, risks, and deviations
1. **`services/api-gateway/requirements-test.txt` does not exist** — the test job will fail at the install step until it's created (suggest `pytest`, and `httpx` if using FastAPI's `TestClient`).
2. **`services/api-gateway/tests/` does not exist** — `pytest services/api-gateway/tests/` will exit with code 5 ("no tests collected") until tests are added. I did not create these files since the task was scoped to the workflow only; the workflow will go green once they land.
3. **Image name casing**: GHCR requires lowercase image names. If the GitHub repo name contains uppercase letters, `ghcr.io/${{ github.repository }}/api-gateway` would fail at push; a lowercase hardcode or a lowercasing step would then be needed.
4. No deviations from the requested requirements; all specified action versions (`checkout@v4`, `setup-python@v5`, `login-action@v3`, `build-push-action@v6`) are used as specified.
