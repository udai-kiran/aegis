"""AI strategy allocation endpoints (tenant-scoped)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import require_role
from app.audit import record_audit
from app.database import get_db
from app.models import AIDecision, ShadowResult, User
from app.schemas import (
    AIDecisionResponse,
    AllocationRequest,
    ShadowResultCreate,
    ShadowResultResponse,
)

router = APIRouter(prefix="/tenants/{tenant_id}/ai", tags=["ai-allocation"])


def _check_tenant_access(tenant_id: uuid.UUID, current_user: User) -> None:
    if current_user.role != "PLATFORM_ADMIN" and current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied"
        )


@router.post(
    "/allocate",
    response_model=AIDecisionResponse,
    status_code=status.HTTP_201_CREATED,
)
def allocate(
    tenant_id: uuid.UUID,
    body: AllocationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Run AI allocation for a portfolio and store the decision."""
    _check_tenant_access(tenant_id, current_user)

    from app.models import Portfolio

    portfolio = (
        db.query(Portfolio)
        .filter(Portfolio.id == body.portfolio_id, Portfolio.tenant_id == tenant_id)
        .first()
    )
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found"
        )
    if body.mode == "LIVE" and portfolio.trading_mode not in ("LIVE", "PAPER"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="LIVE allocation requires a LIVE or PAPER portfolio",
        )

    from app.intelligence.allocator import compute_allocation

    result = compute_allocation(db, tenant_id, body.portfolio_id, mode=body.mode)

    decision = AIDecision(
        tenant_id=tenant_id,
        portfolio_id=body.portfolio_id,
        market_regime_id=result["market_regime_id"],
        strategy_weights=result["strategy_weights"],
        cash_weight=result["cash_weight"],
        confidence=result["confidence"],
        mode=result["mode"],
        reward_params=result["reward_params"],
        context_snapshot=result["context_snapshot"],
        explanation=result["explanation"],
    )
    db.add(decision)
    db.flush()

    record_audit(
        db,
        action="ai_allocation_computed",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"ai_decision:{decision.id}",
        after_state={
            "mode": result["mode"],
            "cash_weight": result["cash_weight"],
            "confidence": result["confidence"],
        },
    )
    db.commit()
    db.refresh(decision)
    return decision


@router.get("/decisions", response_model=list[AIDecisionResponse])
def list_decisions(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List AI decisions for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(AIDecision)
        .filter(AIDecision.tenant_id == tenant_id)
        .order_by(AIDecision.created_at.desc())
        .all()
    )


@router.get("/decisions/{decision_id}", response_model=AIDecisionResponse)
def get_decision(
    tenant_id: uuid.UUID,
    decision_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """Get a single AI decision."""
    _check_tenant_access(tenant_id, current_user)
    decision = (
        db.query(AIDecision)
        .filter(AIDecision.id == decision_id, AIDecision.tenant_id == tenant_id)
        .first()
    )
    if not decision:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="AI decision not found"
        )
    return decision


@router.post(
    "/shadow-results",
    response_model=ShadowResultResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_shadow_result(
    tenant_id: uuid.UUID,
    body: ShadowResultCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER")
    ),
):
    """Record a shadow evaluation result."""
    _check_tenant_access(tenant_id, current_user)

    # Verify the AI decision exists and belongs to tenant
    decision = (
        db.query(AIDecision)
        .filter(AIDecision.id == body.ai_decision_id, AIDecision.tenant_id == tenant_id)
        .first()
    )
    if not decision:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="AI decision not found"
        )

    from app.models import StrategyConfig

    config = (
        db.query(StrategyConfig)
        .filter(
            StrategyConfig.id == body.strategy_config_id,
            StrategyConfig.tenant_id == tenant_id,
        )
        .first()
    )
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Strategy config not found",
        )
    if config.portfolio_id != decision.portfolio_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Strategy config does not belong to the decision portfolio",
        )

    shadow = ShadowResult(
        tenant_id=tenant_id,
        portfolio_id=decision.portfolio_id,
        ai_decision_id=body.ai_decision_id,
        strategy_config_id=body.strategy_config_id,
        hypothetical_return=body.hypothetical_return,
        actual_return=body.actual_return,
        evaluation_start=body.evaluation_start,
        evaluation_end=body.evaluation_end,
    )
    db.add(shadow)
    db.flush()

    record_audit(
        db,
        action="shadow_result_recorded",
        tenant_id=tenant_id,
        user_id=current_user.id,
        resource=f"shadow_result:{shadow.id}",
        after_state={
            "hypothetical_return": body.hypothetical_return,
            "actual_return": body.actual_return,
        },
    )
    db.commit()
    db.refresh(shadow)
    return shadow


@router.get("/shadow-results", response_model=list[ShadowResultResponse])
def list_shadow_results(
    tenant_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role("PLATFORM_ADMIN", "TENANT_ADMIN", "RESEARCHER", "TRADER")
    ),
):
    """List shadow evaluation results for a tenant."""
    _check_tenant_access(tenant_id, current_user)
    return (
        db.query(ShadowResult)
        .filter(ShadowResult.tenant_id == tenant_id)
        .order_by(ShadowResult.created_at.desc())
        .all()
    )
