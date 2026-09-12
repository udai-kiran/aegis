"""Tenant management endpoints (platform admin only)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import Tenant, User
from app.schemas import TenantCreate, TenantResponse, TenantUpdate

router = APIRouter(prefix="/tenants", tags=["tenants"])


@router.get("", response_model=list[TenantResponse])
def list_tenants(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """List all tenants (platform admin only)."""
    return db.query(Tenant).order_by(Tenant.created_at).all()


@router.post("", response_model=TenantResponse, status_code=status.HTTP_201_CREATED)
def create_tenant(
    body: TenantCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """Create a new tenant (platform admin only)."""
    if db.query(Tenant).filter(Tenant.name == body.name).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Tenant name already exists"
        )

    tenant = Tenant(**body.model_dump())
    db.add(tenant)
    db.flush()

    record_audit(
        db,
        action="tenant_created",
        tenant_id=tenant.id,
        user_id=current_user.id,
        resource=f"tenant:{tenant.id}",
        after_state=body.model_dump(),
    )
    db.commit()
    db.refresh(tenant)
    return tenant


@router.get("/{tenant_id}", response_model=TenantResponse)
def get_tenant(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(
            "PLATFORM_ADMIN",
            "TENANT_ADMIN",
            "TRADER",
            "RESEARCHER",
            "RISK_MANAGER",
            "VIEWER",
        )
    ),
):
    """Get a single tenant. Platform admins see any; tenant users see only their own."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )

    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found"
        )
    return tenant


@router.patch("/{tenant_id}", response_model=TenantResponse)
def update_tenant(
    tenant_id: uuid.UUID,
    body: TenantUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """Update tenant details (platform admin only)."""
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found"
        )

    before = {
        c.key: getattr(tenant, c.key)
        for c in Tenant.__table__.columns
        if c.key not in ("id", "created_at", "updated_at")
    }
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(tenant, key, value)
    db.flush()

    record_audit(
        db,
        action="tenant_updated",
        tenant_id=tenant.id,
        user_id=current_user.id,
        resource=f"tenant:{tenant.id}",
        before_state=before,
        after_state=updates,
    )
    db.commit()
    db.refresh(tenant)
    return tenant
