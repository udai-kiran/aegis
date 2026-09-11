# Aegis Trader

Multi-tenant, AI-assisted algorithmic trading platform.

## Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Foundation** | Docker Compose, networks, infra services | ✅ Done ([PR #1](https://github.com/udai-kiran/aegis/pull/1)) |
| **Phase 1** | Tenant model, users, RBAC, APIs, audit | ✅ Done ([PR #2](https://github.com/udai-kiran/aegis/pull/2)) |
| **Phase 2** | Historical data, strategies, backtesting | 🔲 Not started |
| **Phase 3** | Live data, paper trading, portfolio/risk | 🔲 Not started |
| **Phase 4** | Broker execution, reconciliation | 🔲 Not started |
| **Phase 5** | AI strategy selection | 🔲 Not started |
| **Phase 6** | LLM supervisor, advanced AI | 🔲 Not started |

## Quick Start

```bash
make up        # start production stack (Traefik on port 80)
make dev-up    # start with dev ports (postgres:5432, redis:6379, api:8000, minio:9000/9001)
make down      # stop
make clean     # stop and remove volumes
```

## Architecture

See [aegis_trader_multi_tenant_prd.md](aegis_trader_multi_tenant_prd.md) for the full PRD.
