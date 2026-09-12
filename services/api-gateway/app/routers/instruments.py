"""Instrument management endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import get_current_user, require_role
from app.audit import record_audit
from app.database import get_db
from app.models import Instrument, User
from app.schemas import InstrumentCreate, InstrumentResponse

router = APIRouter(prefix="/instruments", tags=["instruments"])


@router.get("", response_model=list[InstrumentResponse])
def list_instruments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all active instruments. Any authenticated user can view."""
    return (
        db.query(Instrument)
        .filter(Instrument.is_active.is_(True))
        .order_by(Instrument.symbol)
        .all()
    )


@router.post("", response_model=InstrumentResponse, status_code=status.HTTP_201_CREATED)
def create_instrument(
    body: InstrumentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """Create a new instrument. Platform admin only."""
    existing = (
        db.query(Instrument)
        .filter(Instrument.symbol == body.symbol, Instrument.exchange == body.exchange)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Instrument {body.symbol}:{body.exchange} already exists",
        )

    instrument = Instrument(
        symbol=body.symbol,
        exchange=body.exchange,
        instrument_type=body.instrument_type,
        name=body.name,
        lot_size=body.lot_size,
        tick_size=body.tick_size,
    )
    db.add(instrument)
    db.flush()

    record_audit(
        db,
        action="instrument_created",
        user_id=current_user.id,
        resource=f"instrument:{instrument.id}",
        after_state=body.model_dump(),
    )
    db.commit()
    db.refresh(instrument)
    return instrument


@router.get("/{instrument_id}", response_model=InstrumentResponse)
def get_instrument(
    instrument_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single instrument by ID. Any authenticated user can view."""
    instrument = db.query(Instrument).filter(Instrument.id == instrument_id).first()
    if not instrument:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Instrument not found"
        )
    return instrument
