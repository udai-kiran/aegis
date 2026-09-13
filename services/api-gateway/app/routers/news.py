"""Market news ingestion endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import NewsItem, User
from app.schemas import NewsItemCreate, NewsItemResponse

router = APIRouter(prefix="/tenants/{tenant_id}/news", tags=["news"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post("", response_model=NewsItemResponse, status_code=status.HTTP_201_CREATED)
def create_news(
    tenant_id: uuid.UUID,
    body: NewsItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Ingest a market news item with sentiment."""
    _check_tenant_access(tenant_id, current_user)

    item = NewsItem(
        tenant_id=tenant_id,
        headline=body.headline,
        source=body.source,
        url=body.url,
        symbols=body.symbols,
        sentiment_score=body.sentiment_score,
        sentiment_label=body.sentiment_label,
        published_at=body.published_at,
    )
    db.add(item)
    db.flush()

    record_audit(
        db,
        action="news_item_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"news_item:{item.id}",
        after_state={
            "headline": body.headline,
            "sentiment_label": body.sentiment_label,
            "sentiment_score": body.sentiment_score,
        },
    )
    db.commit()
    db.refresh(item)
    return item


@router.get("", response_model=list[NewsItemResponse])
def list_news(
    tenant_id: uuid.UUID,
    symbol: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List news items for a tenant, optionally filtered by symbol."""
    _check_tenant_access(tenant_id, current_user)
    query = db.query(NewsItem).filter(NewsItem.tenant_id == tenant_id)
    if symbol:
        # Filter where the symbol appears in the JSON array
        # For SQLite (tests) and PostgreSQL compatibility, use contains
        query = query.filter(NewsItem.symbols.contains(symbol))
    return query.order_by(NewsItem.published_at.desc()).limit(limit).all()


@router.get("/{news_id}", response_model=NewsItemResponse)
def get_news(
    tenant_id: uuid.UUID,
    news_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """Get a single news item by ID."""
    _check_tenant_access(tenant_id, current_user)
    item = (
        db.query(NewsItem)
        .filter(NewsItem.id == news_id, NewsItem.tenant_id == tenant_id)
        .first()
    )
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="News item not found"
        )
    return item
