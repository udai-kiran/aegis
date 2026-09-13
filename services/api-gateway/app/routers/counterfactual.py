"""Counterfactual evaluation endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.database import get_db
from app.models import AIDecision, User
from app.schemas import CounterfactualRequest, CounterfactualResponse

router = APIRouter(
    prefix="/tenants/{tenant_id}/ai/counterfactual", tags=["counterfactual"]
)


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post("/evaluate", response_model=CounterfactualResponse)
def evaluate(
    tenant_id: uuid.UUID,
    body: CounterfactualRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Run counterfactual evaluation for an AI decision."""
    _check_tenant_access(tenant_id, current_user)

    # Verify decision exists and belongs to tenant
    decision = (
        db.query(AIDecision)
        .filter(
            AIDecision.id == body.ai_decision_id,
            AIDecision.tenant_id == tenant_id,
        )
        .first()
    )
    if not decision:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="AI decision not found"
        )

    from app.intelligence.counterfactual import evaluate_counterfactual

    result = evaluate_counterfactual(
        db,
        tenant_id,
        body.ai_decision_id,
        body.evaluation_start,
        body.evaluation_end,
    )
    return result
