"""Market regime endpoints (shared, not tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.database import get_db
from app.models import MarketRegime, User
from app.schemas import MarketRegimeResponse, RegimeComputeRequest

router = APIRouter(prefix="/market-regimes", tags=["market-regimes"])


@router.post(
    "/compute", response_model=MarketRegimeResponse, status_code=status.HTTP_201_CREATED
)
def compute_regime(
    body: RegimeComputeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Compute and store the current market regime for a symbol."""
    from app.intelligence.regime import compute_regime as _compute

    # Use current_user tenant_id for OHLCV data access
    result = _compute(
        db,
        symbol=body.symbol,
        exchange=body.exchange,
        timeframe=body.timeframe,
        lookback_bars=body.lookback_bars,
        tenant_id=current_user.tenant_id,
    )

    regime = MarketRegime(
        regime_label=result["regime_label"],
        features=result["features"],
        confidence=result["confidence"],
        symbol=body.symbol,
        exchange=body.exchange,
        timeframe=body.timeframe,
    )
    db.add(regime)
    db.commit()
    db.refresh(regime)
    return regime


@router.get("", response_model=list[MarketRegimeResponse])
def list_regimes(
    symbol: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List recent market regimes, optionally filtered by symbol."""
    query = db.query(MarketRegime)
    if symbol:
        query = query.filter(MarketRegime.symbol == symbol)
    return query.order_by(MarketRegime.computed_at.desc()).limit(limit).all()


@router.get("/{regime_id}", response_model=MarketRegimeResponse)
def get_regime(
    regime_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """Get a single market regime by ID."""
    regime = db.query(MarketRegime).filter(MarketRegime.id == regime_id).first()
    if not regime:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Market regime not found"
        )
    return regime
