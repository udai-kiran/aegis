"""Broker account endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.broker.credential_vault import encrypt_credentials
from app.database import get_db
from app.models import BrokerAccount, Tenant, User
from app.schemas import (
    BrokerAccountCreate,
    BrokerAccountResponse,
    BrokerAccountUpdate,
)

router = APIRouter(
    prefix="/tenants/{tenant_id}/broker-accounts", tags=["broker-accounts"]
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post(
    "", response_model=BrokerAccountResponse, status_code=status.HTTP_201_CREATED
)
def create_broker_account(
    tenant_id: uuid.UUID,
    body: BrokerAccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Create a broker account within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found"
        )

    encrypted = (
        encrypt_credentials(body.credentials) if body.credentials is not None else None
    )
    account = BrokerAccount(
        tenant_id=tenant_id,
        broker_type=body.broker_type,
        display_name=body.display_name,
        encrypted_credentials=encrypted,
        credential_metadata=body.credential_metadata,
        is_primary=body.is_primary,
    )
    db.add(account)
    db.flush()

    record_audit(
        db,
        action="broker_account_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"broker_account:{account.id}",
        after_state={
            "broker_type": body.broker_type,
            "display_name": body.display_name,
            "is_primary": body.is_primary,
        },
    )
    db.commit()
    db.refresh(account)
    return account


@router.get("", response_model=list[BrokerAccountResponse])
def list_broker_accounts(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RISK_MANAGER")
    ),
):
    """List all broker accounts for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(BrokerAccount)
        .filter(BrokerAccount.tenant_id == tenant_id)
        .order_by(BrokerAccount.created_at)
        .all()
    )


@router.get("/{account_id}", response_model=BrokerAccountResponse)
def get_broker_account(
    tenant_id: uuid.UUID,
    account_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "TRADER", "RISK_MANAGER")
    ),
):
    """Get a single broker account."""
    _check_tenant_access(tenant_id, current_user)

    account = (
        db.query(BrokerAccount)
        .filter(BrokerAccount.id == account_id, BrokerAccount.tenant_id == tenant_id)
        .first()
    )
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Broker account not found"
        )
    return account


@router.patch("/{account_id}", response_model=BrokerAccountResponse)
def update_broker_account(
    tenant_id: uuid.UUID,
    account_id: uuid.UUID,
    body: BrokerAccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Update a broker account."""
    _check_tenant_access(tenant_id, current_user)

    account = (
        db.query(BrokerAccount)
        .filter(BrokerAccount.id == account_id, BrokerAccount.tenant_id == tenant_id)
        .first()
    )
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Broker account not found"
        )

    before = {"display_name": account.display_name, "status": account.status}
    updates = body.model_dump(exclude_unset=True)
    if "credentials" in updates and updates["credentials"] is not None:
        account.encrypted_credentials = encrypt_credentials(updates["credentials"])
    for key, value in updates.items():
        if key == "credentials":
            continue
        setattr(account, key, value)
    db.flush()

    record_audit(
        db,
        action="broker_account_updated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"broker_account:{account_id}",
        before_state=before,
        after_state={
            key: value
            for key, value in body.model_dump(exclude_unset=True, mode="json").items()
            if key != "credentials"
        },
    )
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_broker_account(
    tenant_id: uuid.UUID,
    account_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN", "TENANT_ADMIN")),
):
    """Deactivate a broker account (soft delete)."""
    _check_tenant_access(tenant_id, current_user)

    account = (
        db.query(BrokerAccount)
        .filter(BrokerAccount.id == account_id, BrokerAccount.tenant_id == tenant_id)
        .first()
    )
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Broker account not found"
        )

    account.status = "INACTIVE"
    db.flush()

    record_audit(
        db,
        action="broker_account_deactivated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"broker_account:{account_id}",
        before_state={"display_name": account.display_name, "status": "ACTIVE"},
    )
    db.commit()
