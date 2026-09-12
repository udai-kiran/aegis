"""Audit event recording helper."""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session


def record_audit(
    db: Session,
    *,
    action: str,
    tenant_id: uuid.UUID | None = None,
    user_id: uuid.UUID | None = None,
    resource: str | None = None,
    before_state: dict | None = None,
    after_state: dict | None = None,
    ip_address: str | None = None,
) -> None:
    """Insert an audit event row."""
    from app.models import AuditEvent

    event = AuditEvent(
        tenant_id=tenant_id,
        user_id=user_id,
        action=action,
        resource=resource,
        before_state=before_state,
        after_state=after_state,
        ip_address=ip_address,
    )
    db.add(event)
    db.flush()
