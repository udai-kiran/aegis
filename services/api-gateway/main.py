"""Aegis Trader - API Gateway service."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine
from app.routers import (
    auth,
    audit,
    backtests,
    instruments,
    ohlcv,
    portfolios,
    strategies,
    strategy_configs,
    tenants,
    users,
)


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
app.include_router(instruments.router, prefix="/api")
app.include_router(ohlcv.router, prefix="/api")
app.include_router(strategies.router, prefix="/api")
app.include_router(strategy_configs.router, prefix="/api")
app.include_router(backtests.router, prefix="/api")
