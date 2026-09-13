"""Kill switch endpoints: halt/resume trading at tenant, portfolio, or broker-account scope."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import BrokerAccount, Portfolio, Tenant, User
from app.schemas import KillSwitchAction, KillSwitchStatus

router = APIRouter(prefix="/tenants/{tenant_id}/kill-switch", tags=["kill-switch"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


def _get_tenant(db: Session, tenant_id: uuid.UUID) -> Tenant:
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Tenant not found"
        )
    return tenant


@router.get("", response_model=KillSwitchStatus)
def get_kill_switch_status(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Get the current kill switch status for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    tenant = _get_tenant(db, tenant_id)

    portfolios_halted = (
        db.query(Portfolio.id)
        .filter(Portfolio.tenant_id == tenant_id, Portfolio.trading_halted.is_(True))
        .all()
    )
    broker_accounts_halted = (
        db.query(BrokerAccount.id)
        .filter(
            BrokerAccount.tenant_id == tenant_id,
            BrokerAccount.status == "HALTED",
        )
        .all()
    )

    return KillSwitchStatus(
        tenant_halted=tenant.trading_halted,
        portfolios_halted=[row[0] for row in portfolios_halted],
        broker_accounts_halted=[row[0] for row in broker_accounts_halted],
    )


@router.post("")
def apply_kill_switch(
    tenant_id: uuid.UUID,
    body: KillSwitchAction,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Halt or resume trading at tenant, portfolio, or broker-account scope."""
    _check_tenant_access(tenant_id, current_user)
    scope = body.scope
    action = body.action
    target_id = body.target_id

    if scope == "TENANT":
        tenant = _get_tenant(db, tenant_id)
        tenant.trading_halted = action == "HALT"
    elif scope == "PORTFOLIO":
        portfolio = (
            db.query(Portfolio)
            .filter(Portfolio.id == target_id, Portfolio.tenant_id == tenant_id)
            .first()
        )
        if not portfolio:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
            )
        portfolio.trading_halted = action == "HALT"
    elif scope == "BROKER_ACCOUNT":
        broker_account = (
            db.query(BrokerAccount)
            .filter(
                BrokerAccount.id == target_id,
                BrokerAccount.tenant_id == tenant_id,
            )
            .first()
        )
        if not broker_account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Broker account not found",
            )
        broker_account.status = "HALTED" if action == "HALT" else "ACTIVE"
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid scope",
        )

    db.flush()

    record_audit(
        db,
        action=f"kill_switch_{action.lower()}",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"kill_switch:{scope}:{target_id}",
        after_state=body.model_dump(mode="json"),
    )
    db.commit()

    return {
        "status": "ok",
        "scope": scope,
        "action": action,
        "target_id": str(target_id),
    }


@router.post("/emergency-halt")
def emergency_halt_all(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("PLATFORM_ADMIN")),
):
    """Emergency halt: stop all trading for a tenant across every scope."""
    _check_tenant_access(tenant_id, current_user)
    tenant = _get_tenant(db, tenant_id)

    tenant.trading_halted = True
    db.query(Portfolio).filter(Portfolio.tenant_id == tenant_id).update(
        {"trading_halted": True}
    )
    db.query(BrokerAccount).filter(BrokerAccount.tenant_id == tenant_id).update(
        {"status": "HALTED"}
    )
    db.flush()

    record_audit(
        db,
        action="emergency_halt",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"kill_switch:ALL:{tenant_id}",
    )
    db.commit()

    return {"status": "halted", "scope": "ALL"}
