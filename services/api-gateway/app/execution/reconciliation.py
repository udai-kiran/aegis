"""Reconciliation engine: compare internal vs broker positions."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.execution.engine import _resolve_broker
from app.models import BrokerAccount, Portfolio, Position

logger = logging.getLogger(__name__)


class ReconciliationEngine:
    """Compares internal position records against broker-reported positions."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def reconcile(self, tenant_id: uuid.UUID, broker_account_id: uuid.UUID) -> dict:
        """Compare internal and broker positions and return a reconciliation report."""
        broker_account = (
            self.db.query(BrokerAccount)
            .filter(BrokerAccount.id == broker_account_id)
            .first()
        )
        if broker_account is None:
            raise ValueError(f"Broker account {broker_account_id} not found")
        if broker_account.tenant_id != tenant_id:
            raise ValueError("Broker account does not belong to tenant")

        broker = _resolve_broker(self.db, broker_account)

        # Internal positions (MVP: all positions for the tenant).
        internal_positions = [
            {
                "symbol": p.symbol,
                "exchange": p.exchange,
                "quantity": float(p.quantity),
                "avg_entry_price": float(p.avg_entry_price),
            }
            for p in self.db.query(Position)
            .filter(Position.tenant_id == tenant_id)
            .all()
        ]

        # Broker-reported positions (MVP: broker stubs read the same DB rows).
        broker_positions: list[dict] = []
        portfolios = (
            self.db.query(Portfolio).filter(Portfolio.tenant_id == tenant_id).all()
        )
        for portfolio in portfolios:
            broker_positions.extend(broker.get_positions(tenant_id, portfolio.id))

        internal_map = {(p["symbol"], p["exchange"]): p for p in internal_positions}
        broker_map = {(p["symbol"], p["exchange"]): p for p in broker_positions}

        matched: list[str] = []
        mismatches: list[dict] = []
        internal_only: list[str] = []
        broker_only: list[str] = []

        for key, internal in internal_map.items():
            broker_pos = broker_map.get(key)
            if broker_pos is None:
                internal_only.append(key[0])
            elif (
                internal["quantity"] == broker_pos["quantity"]
                and internal["avg_entry_price"] == broker_pos["avg_entry_price"]
            ):
                matched.append(key[0])
            else:
                mismatches.append(
                    {
                        "symbol": key[0],
                        "exchange": key[1],
                        "internal_quantity": internal["quantity"],
                        "broker_quantity": broker_pos["quantity"],
                        "internal_avg_entry_price": internal["avg_entry_price"],
                        "broker_avg_entry_price": broker_pos["avg_entry_price"],
                    }
                )

        for key in broker_map:
            if key not in internal_map:
                broker_only.append(key[0])

        status = (
            "MATCHED"
            if not mismatches and not internal_only and not broker_only
            else "MISMATCHED"
        )
        logger.info(
            "Reconciliation for broker account %s: %s (%d matched, %d mismatched)",
            broker_account_id,
            status,
            len(matched),
            len(mismatches),
        )
        return {
            "broker_account_id": str(broker_account_id),
            "status": status,
            "matched_positions": len(matched),
            "mismatched_positions": len(mismatches),
            "internal_only": internal_only,
            "broker_only": broker_only,
            "mismatches": mismatches,
            "reconciled_at": datetime.now(timezone.utc).isoformat(),
        }
