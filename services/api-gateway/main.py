"""Aegis Trader - API Gateway service."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine
from app.routers import auth, tenants, users, portfolios, audit
from app.routers import backtests, ohlcv, strategies
from app.routers import risk_policies, positions, orders, paper_trading, dashboard
from app.routers import broker_accounts
from app.routers import kill_switch, execution
from app.routers import market_regime, strategy_health, ai_allocation


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables on startup."""
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Aegis Trader API", version="0.1.0", lifespan=lifespan)


# Health check (no auth required)
@app.get("/health")
async def health():
    return {"status": "ok"}


# Mount routers under /api prefix
app.include_router(auth.router, prefix="/api")
app.include_router(tenants.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(portfolios.router, prefix="/api")
app.include_router(audit.router, prefix="/api")
app.include_router(ohlcv.router, prefix="/api")
app.include_router(strategies.router, prefix="/api")
app.include_router(strategies.config_router, prefix="/api")
app.include_router(backtests.router, prefix="/api")
app.include_router(risk_policies.router, prefix="/api")
app.include_router(positions.router, prefix="/api")
app.include_router(orders.router, prefix="/api")
app.include_router(paper_trading.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(broker_accounts.router, prefix="/api")
app.include_router(kill_switch.router, prefix="/api")
app.include_router(execution.router, prefix="/api")
app.include_router(market_regime.router, prefix="/api")
app.include_router(strategy_health.router, prefix="/api")
app.include_router(ai_allocation.router, prefix="/api")
