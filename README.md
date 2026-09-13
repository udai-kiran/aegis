# Aegis Trader

Multi-tenant, AI-assisted algorithmic trading platform.

## Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Foundation** | Docker Compose, networks, infra services | ✅ Done ([PR #1](https://github.com/udai-kiran/aegis/pull/1)) |
| **Phase 1** | Tenant model, users, RBAC, APIs, audit | ✅ Done ([PR #2](https://github.com/udai-kiran/aegis/pull/2)) |
| **Phase 2** | Historical data, strategies, backtesting | ✅ Done ([PR #4](https://github.com/udai-kiran/aegis/pull/4)) |
| **Phase 3** | Live data, paper trading, portfolio/risk | ✅ Done ([PR #5](https://github.com/udai-kiran/aegis/pull/5)) |
| **Phase 4** | Broker execution, reconciliation | ✅ Done ([PR #7](https://github.com/udai-kiran/aegis/pull/7)) |
| **Phase 5** | AI strategy selection | ✅ Done ([PR #8](https://github.com/udai-kiran/aegis/pull/8)) |
| **Phase 6** | LLM supervisor, advanced AI | ✅ Done |
| **Phase 7** | React dashboard UI | ✅ Done |

## Quick Start

```bash
make up        # start production stack (Traefik on port 80)
make dev-up    # start with dev ports (postgres:5432, redis:6379, api:8000, minio:9000/9001, ui:3000)
make down      # stop
make clean     # stop and remove volumes
```

### Frontend development

```bash
cd services/web-ui
npm install
npm run dev    # starts Vite dev server on http://localhost:5173 (proxies /api → :8000)
```

## Architecture

See [aegis_trader_multi_tenant_prd.md](aegis_trader_multi_tenant_prd.md) for the full PRD.

### Frontend

React 19 + TypeScript 7 dashboard (dark theme) built with Vite 8, Tailwind CSS 4, TanStack Query 5, Zustand 5, and Recharts 3.

**Pages:** Login, Dashboard, Portfolios, Portfolio Detail, Strategies, Backtests, Orders, Risk & Kill Switch, AI Intelligence, Settings (Tenant/Users/Broker Accounts/Audit Log).
