"""Risk policy endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import Portfolio, RiskPolicy, User
from app.schemas import RiskPolicyCreate, RiskPolicyResponse, RiskPolicyUpdate

router = APIRouter(prefix="/tenants/{tenant_id}/risk-policies", tags=["risk-policies"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    """Raise 403 if user is not platform admin and does not belong to the tenant."""
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post("", response_model=RiskPolicyResponse, status_code=status.HTTP_201_CREATED)
def create_risk_policy(
    tenant_id: uuid.UUID,
    body: RiskPolicyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Create a risk policy within a tenant."""
    _check_tenant_access(tenant_id, current_user)

    if body.portfolio_id is not None:
        portfolio = (
            db.query(Portfolio)
            .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
            .first()
        )
        if not portfolio:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
            )

    policy = RiskPolicy(
        tenant_id=tenant_id,
        portfolio_id=body.portfolio_id,
        name=body.name,
        policy_type=body.policy_type,
        max_daily_loss_pct=body.max_daily_loss_pct,
        max_drawdown_pct=body.max_drawdown_pct,
        max_position_pct=body.max_position_pct,
        max_order_value=body.max_order_value,
        max_leverage=body.max_leverage,
        allowed_instruments=body.allowed_instruments,
        trading_windows=body.trading_windows,
    )
    db.add(policy)
    db.flush()

    record_audit(
        db,
        action="risk_policy_created",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"risk_policy:{policy.id}",
        after_state=body.model_dump(mode="json"),
    )
    db.commit()
    db.refresh(policy)
    return policy


@router.get("", response_model=list[RiskPolicyResponse])
def list_risk_policies(
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
    """List all active risk policies for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(RiskPolicy)
        .filter(RiskPolicy.tenant_id == tenant_id, RiskPolicy.is_active.is_(True))
        .order_by(RiskPolicy.created_at)
        .all()
    )


@router.get("/{policy_id}", response_model=RiskPolicyResponse)
def get_risk_policy(
    tenant_id: uuid.UUID,
    policy_id: uuid.UUID,
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
    """Get a single risk policy."""
    _check_tenant_access(tenant_id, current_user)

    policy = (
        db.query(RiskPolicy)
        .filter(RiskPolicy.id == policy_id, RiskPolicy.tenant_id == tenant_id)
        .first()
    )
    if not policy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Risk policy not found"
        )
    return policy


@router.patch("/{policy_id}", response_model=RiskPolicyResponse)
def update_risk_policy(
    tenant_id: uuid.UUID,
    policy_id: uuid.UUID,
    body: RiskPolicyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Update a risk policy."""
    _check_tenant_access(tenant_id, current_user)

    policy = (
        db.query(RiskPolicy)
        .filter(RiskPolicy.id == policy_id, RiskPolicy.tenant_id == tenant_id)
        .first()
    )
    if not policy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Risk policy not found"
        )

    before = {"name": policy.name, "policy_type": policy.policy_type}
    updates = body.model_dump(exclude_unset=True)
    if "portfolio_id" in updates and updates["portfolio_id"] is not None:
        portfolio = (
            db.query(Portfolio)
            .filter(Portfolio.id == updates["portfolio_id"], Portfolio.tenant_id == tenant_id)
            .first()
        )
        if not portfolio:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            )
    for key, value in updates.items():
        setattr(policy, key, value)
    db.flush()

    record_audit(
        db,
        action="risk_policy_updated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"risk_policy:{policy_id}",
        before_state=before,
        after_state=body.model_dump(exclude_unset=True, mode="json"),
    )
    db.commit()
    db.refresh(policy)
    return policy


@router.delete("/{policy_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_risk_policy(
    tenant_id: uuid.UUID,
    policy_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RISK_MANAGER")
    ),
):
    """Deactivate a risk policy (soft delete)."""
    _check_tenant_access(tenant_id, current_user)

    policy = (
        db.query(RiskPolicy)
        .filter(RiskPolicy.id == policy_id, RiskPolicy.tenant_id == tenant_id)
        .first()
    )
    if not policy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Risk policy not found"
        )

    policy.is_active = False
    db.flush()

    record_audit(
        db,
        action="risk_policy_deactivated",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"risk_policy:{policy_id}",
        before_state={"name": policy.name, "is_active": True},
    )
    db.commit()
