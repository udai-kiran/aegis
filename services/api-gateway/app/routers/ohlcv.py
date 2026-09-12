"""OHLCV market data endpoints (tenant-scoped)."""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import OHLCVBar, Tenant, User
from app.schemas import OHLCVBarBulkCreate, OHLCVBarResponse

router = APIRouter(prefix="/tenants/{tenant_id}/ohlcv", tags=["ohlcv"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")


@router.post("", status_code=status.HTTP_201_CREATED)
def upload_ohlcv_bars(
    tenant_id: uuid.UUID,
    body: OHLCVBarBulkCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")),
):
    """Bulk upload OHLCV bars for a tenant."""
    _check_tenant_access(tenant_id, current_user)

    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found")

    bars = [
        OHLCVBar(
            tenant_id=tenant_id,
            symbol=bar.symbol,
            exchange=bar.exchange,
            timeframe=bar.timeframe,
            timestamp=bar.timestamp,
            open=bar.open,
            high=bar.high,
            low=bar.low,
            close=bar.close,
            volume=bar.volume,
        )
        for bar in body.bars
    ]
    db.add_all(bars)
    db.flush()

    record_audit(
        db,
        action="ohlcv_uploaded",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource="ohlcv",
        after_state={"count": len(body.bars)},
    )
    db.commit()
    return {"count": len(body.bars)}


@router.get("", response_model=list[OHLCVBarResponse])
def list_ohlcv_bars(
    tenant_id: uuid.UUID,
    symbol: str,
    exchange: str = "NSE",
    timeframe: str = "1d",
    start: datetime | None = None,
    end: datetime | None = None,
    limit: int = 1000,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RESEARCHER", "RISK_MANAGER", "VIEWER")),
):
    """Query OHLCV bars for a symbol within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    query = db.query(OHLCVBar).filter(
        OHLCVBar.tenant_id == tenant_id,
        OHLCVBar.symbol == symbol,
        OHLCVBar.exchange == exchange,
        OHLCVBar.timeframe == timeframe,
    )
    if start is not None:
        query = query.filter(OHLCVBar.timestamp >= start)
    if end is not None:
        query = query.filter(OHLCVBar.timestamp <= end)
    return query.order_by(OHLCVBar.timestamp).limit(limit).all()