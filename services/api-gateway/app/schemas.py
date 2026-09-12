"""Pydantic request/response schemas for Phase 1 & 2 APIs."""

from __future__ import annotations

import uuid
from datetime import date, datetime

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


# --- Instrument ---
class InstrumentCreate(BaseModel):
    symbol: str = Field(max_length=20)
    exchange: str = Field(default="NSE", max_length=20)
    instrument_type: str = Field(default="EQUITY", max_length=20)
    name: str = Field(max_length=255)
    lot_size: int = Field(default=1, ge=1)
    tick_size: float = Field(default=0.05, gt=0)


class InstrumentResponse(BaseModel):
    id: uuid.UUID
    symbol: str
    exchange: str
    instrument_type: str
    name: str
    lot_size: int
    tick_size: float
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- OHLCV ---
class OHLCVBarCreate(BaseModel):
    timeframe: str = Field(default="1d", max_length=5)
    timestamp: datetime
    open: float = Field(allow_inf_nan=False)
    high: float = Field(allow_inf_nan=False)
    low: float = Field(allow_inf_nan=False)
    close: float = Field(allow_inf_nan=False)
    volume: int = Field(default=0, ge=0)


class OHLCVBarResponse(BaseModel):
    id: uuid.UUID
    instrument_id: uuid.UUID
    timeframe: str
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: int
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Strategy ---
class StrategyCreate(BaseModel):
    tenant_id: uuid.UUID | None = None
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    version: str = Field(default="1.0.0", max_length=20)
    owner_type: str = Field(default="PLATFORM", max_length=10)
    code_reference: str | None = Field(default=None, max_length=500)


class StrategyUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    version: str | None = None
    status: str | None = None
    code_reference: str | None = None


class StrategyResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID | None
    name: str
    description: str | None
    version: str
    owner_type: str
    status: str
    code_reference: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Strategy Config ---
class StrategyConfigCreate(BaseModel):
    portfolio_id: uuid.UUID
    strategy_id: uuid.UUID
    parameters: dict = Field(default_factory=dict)
    lifecycle_status: str = Field(default="DEVELOPMENT", max_length=30)


class StrategyConfigUpdate(BaseModel):
    parameters: dict | None = None
    lifecycle_status: str | None = None
    is_active: bool | None = None


class StrategyConfigResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_id: uuid.UUID
    parameters: dict
    lifecycle_status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Backtest ---
class BacktestRunCreate(BaseModel):
    portfolio_id: uuid.UUID
    strategy_config_id: uuid.UUID
    start_date: date
    end_date: date
    timeframe: str = Field(default="1d", max_length=5)
    parameters: dict = Field(default_factory=dict)


class BacktestRunResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    portfolio_id: uuid.UUID
    strategy_config_id: uuid.UUID
    status: str
    start_date: date
    end_date: date
    timeframe: str
    parameters: dict
    metrics: dict | None
    error_message: str | None
    created_at: datetime
    completed_at: datetime | None

    model_config = {"from_attributes": True}
