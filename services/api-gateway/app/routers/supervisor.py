"""LLM Supervisor recommendation endpoints (tenant-scoped, PRD §35)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import AIDecision, LLMSupervisorAction, Portfolio, User
from app.schemas import SupervisorRecommendRequest, SupervisorActionResponse

router = APIRouter(prefix="/tenants/{tenant_id}/ai/supervisor", tags=["llm-supervisor"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post(
    "/recommend",
    response_model=list[SupervisorActionResponse],
    status_code=status.HTTP_201_CREATED,
)
def recommend(
    tenant_id: uuid.UUID,
    body: SupervisorRecommendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Generate and store LLM supervisor recommendations for a portfolio."""
    _check_tenant_access(tenant_id, current_user)

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )

    if body.decision_id is not None:
        decision = (
            db.query(AIDecision)
            .filter(
                AIDecision.id == body.decision_id, AIDecision.tenant_id == tenant_id
            )
            .first()
        )
        if not decision:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="AI decision not found"
            )

    from app.intelligence.supervisor import generate_recommendations

    recs = generate_recommendations(
        db, tenant_id, body.portfolio_id, decision_id=body.decision_id
    )

    actions = []
    for rec in recs:
        action = LLMSupervisorAction(
            tenant_id=tenant_id,
            portfolio_id=body.portfolio_id,
            decision_id=body.decision_id,
            action_type=rec["action_type"],
            recommendation=rec["recommendation"],
            reasoning=rec["reasoning"],
            confidence=rec["confidence"],
            status="PENDING",
        )
        db.add(action)
        db.flush()

        record_audit(
            db,
            action="llm_supervisor_recommend",
            tenant_id=tenant_id,
            user_id=current_user.id,
            resource=f"supervisor_action:{action.id}",
            after_state={
                "action_type": rec["action_type"],
                "portfolio_id": str(body.portfolio_id),
                "decision_id": str(body.decision_id) if body.decision_id else None,
                "confidence": rec["confidence"],
            },
        )
        actions.append(action)

    db.commit()
    for a in actions:
        db.refresh(a)
    return actions


@router.get("/actions", response_model=list[SupervisorActionResponse])
def list_actions(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List all supervisor actions for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(LLMSupervisorAction)
        .filter(LLMSupervisorAction.tenant_id == tenant_id)
        .order_by(LLMSupervisorAction.created_at.desc())
        .all()
    )


@router.get("/actions/{action_id}", response_model=SupervisorActionResponse)
def get_action(
    tenant_id: uuid.UUID,
    action_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """Get a single supervisor action by ID."""
    _check_tenant_access(tenant_id, current_user)
    action = (
        db.query(LLMSupervisorAction)
        .filter(
            LLMSupervisorAction.id == action_id,
            LLMSupervisorAction.tenant_id == tenant_id,
        )
        .first()
    )
    if not action:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Supervisor action not found"
        )
    return action
