"""Pydantic request/response schemas for Phase 1 APIs."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


# --- Auth ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class BootstrapRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


# --- Tenant ---
class TenantCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    default_currency: str = Field(default="INR", max_length=3)
    subscription_plan: str = Field(default="FREE", max_length=50)


class TenantUpdate(BaseModel):
    name: str | None = None
    status: str | None = None
    default_currency: str | None = None
    subscription_plan: str | None = None
    risk_profile: dict | None = None
    resource_limits: dict | None = None
    features_enabled: list | None = None


class TenantResponse(BaseModel):
    id: uuid.UUID
    name: str
    status: str
    subscription_plan: str
    default_currency: str
    risk_profile: dict | None = None
    resource_limits: dict | None = None
    features_enabled: list | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- User ---
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    role: str = Field(default="VIEWER")


class UserUpdate(BaseModel):
    role: str | None = None
    is_active: bool | None = None


class UserResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    email: str
    role: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Portfolio ---
class PortfolioCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    starting_capital: float = Field(default=0, ge=0)
    trading_mode: str = Field(default="PAPER")


class PortfolioUpdate(BaseModel):
    name: str | None = None
    trading_mode: str | None = None


class PortfolioResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    starting_capital: float
    current_equity: float
    cash: float
    trading_mode: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Audit ---
class AuditEventResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    user_id: uuid.UUID | None
    action: str
    resource: str | None
    before_state: dict | None
    after_state: dict | None
    ip_address: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- OHLCV ---
class OHLCVBarCreate(BaseModel):
    symbol: str = Field(max_length=50)
    exchange: str = Field(max_length=20)
    timeframe: str = Field(max_length=10)
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


class OHLCVBarBulkCreate(BaseModel):
    bars: list[OHLCVBarCreate]


class OHLCVBarResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    symbol: str
    exchange: str
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Strategy ---
class StrategyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    version: str = "1.0"
    strategy_type: str = Field(min_length=1, max_length=50)
    description: str | None = None


class StrategyUpdate(BaseModel):
    description: str | None = None
    is_active: bool | None = None


class StrategyResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    name: str
    version: str
    strategy_type: str
    description: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- StrategyConfig ---
class StrategyConfigCreate(BaseModel):
    strategy_id: uuid.UUID
    portfolio_id: uuid.UUID
    parameters: dict = Field(default_factory=dict)


class StrategyConfigUpdate(BaseModel):
    parameters: dict | None = None
    lifecycle_status: str | None = None


class StrategyConfigResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    strategy_id: uuid.UUID
    portfolio_id: uuid.UUID
    parameters: dict
    lifecycle_status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Backtest ---
class BacktestCreate(BaseModel):
    strategy_config_id: uuid.UUID
    symbol: str = Field(max_length=50)
    exchange: str = Field(default="NSE", max_length=20)
    timeframe: str = Field(default="1d", max_length=10)
    start_date: datetime
    end_date: datetime
    parameters: dict = Field(default_factory=dict)


class BacktestResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_config_id: uuid.UUID
    symbol: str
    exchange: str
    timeframe: str
    status: str
    start_date: datetime
    end_date: datetime
    parameters: dict
    metrics: dict | None
    error_message: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
