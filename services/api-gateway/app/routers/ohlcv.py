"""OHLCV market data endpoints (nested under instruments)."""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.auth import get_current_user, require_role
from app.database import get_db
from app.models import Instrument, OHLCVBar, User
from app.schemas import OHLCVBarCreate, OHLCVBarResponse

router = APIRouter(prefix="/instruments/{instrument_id}/ohlcv", tags=["market-data"])


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
def upload_ohlcv(
    instrument_id: uuid.UUID,
    bars: list[OHLCVBarCreate],
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """Batch upload OHLCV bars for an instrument. Uses upsert (INSERT ON CONFLICT UPDATE).
    Platform admin only."""
    instrument = db.query(Instrument).filter(Instrument.id == instrument_id).first()
    if not instrument:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Instrument not found"
        )

    if not bars:
        return {"upserted": 0}

    # Deduplicate by conflict key (timeframe, timestamp), keeping last occurrence,
    # so the upsert does not target the same row twice in one statement.
    deduped = {(bar.timeframe, bar.timestamp): bar for bar in bars}

    values = [
        {
            "instrument_id": instrument_id,
            "timeframe": bar.timeframe,
            "timestamp": bar.timestamp,
            "open": bar.open,
            "high": bar.high,
            "low": bar.low,
            "close": bar.close,
            "volume": bar.volume,
        }
        for bar in deduped.values()
    ]

    stmt = insert(OHLCVBar).values(values)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_ohlcv_bar",
        set_={
            "open": stmt.excluded.open,
            "high": stmt.excluded.high,
            "low": stmt.excluded.low,
            "close": stmt.excluded.close,
            "volume": stmt.excluded.volume,
        },
    )
    db.execute(stmt)
    db.commit()
    return {"upserted": len(values)}


@router.get("", response_model=list[OHLCVBarResponse])
def query_ohlcv(
    instrument_id: uuid.UUID,
    timeframe: str = Query(default="1d", max_length=5),
    start: datetime | None = Query(default=None),
    end: datetime | None = Query(default=None),
    limit: int = Query(default=500, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Query OHLCV bars for an instrument. Any authenticated user can query."""
    instrument = db.query(Instrument).filter(Instrument.id == instrument_id).first()
    if not instrument:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Instrument not found"
        )

    q = db.query(OHLCVBar).filter(
        OHLCVBar.instrument_id == instrument_id,
        OHLCVBar.timeframe == timeframe,
    )
    if start:
        q = q.filter(OHLCVBar.timestamp >= start)
    if end:
        q = q.filter(OHLCVBar.timestamp <= end)

    return q.order_by(OHLCVBar.timestamp).limit(limit).all()
