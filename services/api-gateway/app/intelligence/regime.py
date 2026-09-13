"""Market regime classification from OHLCV price data."""

from __future__ import annotations

import logging

import numpy as np
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def compute_regime(
    db: Session,
    symbol: str,
    exchange: str,
    timeframe: str,
    lookback_bars: int = 50,
    tenant_id=None,
) -> dict:
    """Compute market regime from recent OHLCV data.

    Returns a dict with: regime_label, features, confidence.
    tenant_id is required to query tenant-scoped OHLCV data.
    """
    from app.models import OHLCVBar  # lazy import

    query = db.query(OHLCVBar).filter(
        OHLCVBar.symbol == symbol,
        OHLCVBar.exchange == exchange,
        OHLCVBar.timeframe == timeframe,
    )
    if tenant_id is not None:
        query = query.filter(OHLCVBar.tenant_id == tenant_id)
    bars = query.order_by(OHLCVBar.timestamp.desc()).limit(lookback_bars).all()

    if len(bars) < 10:
        return {
            "regime_label": "INSUFFICIENT_DATA",
            "features": {},
            "confidence": 0.0,
        }

    # Build DataFrame from bars (reversed to chronological order)
    bars = list(reversed(bars))
    closes = np.array([float(b.close) for b in bars])
    highs = np.array([float(b.high) for b in bars])
    lows = np.array([float(b.low) for b in bars])
    volumes = np.array([float(b.volume) for b in bars])

    # Guard against zero/negative prices that would cause division errors
    if np.any(closes <= 0):
        return {
            "regime_label": "INSUFFICIENT_DATA",
            "features": {},
            "confidence": 0.0,
        }

    # Compute features
    returns = np.diff(closes) / closes[:-1]
    volatility = float(np.std(returns)) if len(returns) > 1 else 0.0
    avg_return = float(np.mean(returns)) if len(returns) > 0 else 0.0

    # Trend strength: linear regression slope normalized by price
    x = np.arange(len(closes), dtype=float)
    if len(closes) > 1:
        slope = float(np.polyfit(x, closes, 1)[0])
        trend_strength = slope / float(np.mean(closes))
    else:
        trend_strength = 0.0

    # Volume regime: recent volume vs historical average
    if len(volumes) > 10:
        recent_vol = float(np.mean(volumes[-5:]))
        hist_vol = float(np.mean(volumes[:-5]))
        volume_ratio = recent_vol / hist_vol if hist_vol > 0 else 1.0
    else:
        volume_ratio = 1.0

    # Average true range (ATR) as fraction of price
    if len(closes) > 1:
        tr = np.maximum(
            highs[1:] - lows[1:],
            np.maximum(
                np.abs(highs[1:] - closes[:-1]),
                np.abs(lows[1:] - closes[:-1]),
            ),
        )
        atr = float(np.mean(tr))
        atr_pct = atr / float(np.mean(closes))
    else:
        atr_pct = 0.0

    features = {
        "volatility": round(volatility, 6),
        "trend_strength": round(trend_strength, 6),
        "avg_return": round(avg_return, 6),
        "volume_ratio": round(volume_ratio, 4),
        "atr_pct": round(atr_pct, 6),
    }

    # Classify regime
    regime_label, confidence = _classify(volatility, trend_strength, atr_pct)

    logger.info(
        "Regime computed for %s/%s/%s: %s (confidence=%.2f)",
        symbol,
        exchange,
        timeframe,
        regime_label,
        confidence,
    )
    return {
        "regime_label": regime_label,
        "features": features,
        "confidence": confidence,
    }


def _classify(
    volatility: float, trend_strength: float, atr_pct: float
) -> tuple[str, float]:
    """Rule-based regime classification. Returns (label, confidence)."""
    high_vol = volatility > 0.02
    strong_trend = abs(trend_strength) > 0.001

    if high_vol and strong_trend:
        label = "HIGH_VOLATILITY_TRENDING"
        confidence = min(0.6 + abs(trend_strength) * 100, 0.95)
    elif high_vol and not strong_trend:
        label = "HIGH_VOLATILITY_MEAN_REVERTING"
        confidence = min(0.5 + volatility * 10, 0.90)
    elif not high_vol and strong_trend:
        label = "LOW_VOLATILITY_TRENDING"
        confidence = min(0.6 + abs(trend_strength) * 100, 0.95)
    else:
        label = "LOW_VOLATILITY_RANGE_BOUND"
        confidence = 0.7

    return label, round(confidence, 4)
