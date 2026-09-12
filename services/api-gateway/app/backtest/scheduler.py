"""Backtest scheduler with per-tenant concurrency quotas (PRD §22)."""
from __future__ import annotations

import collections
import logging
import threading
import uuid

from sqlalchemy.orm import Session

from app.backtest.engine import run_backtest
from app.database import SessionLocal
from app.models import BacktestRun

logger = logging.getLogger(__name__)


class BacktestScheduler:
    """Multi-tenant backtest scheduler with per-tenant concurrency quotas."""

    def __init__(self, default_max_concurrent: int = 5) -> None:
        self._default_max_concurrent = default_max_concurrent
        self._tenant_limits: dict[uuid.UUID, int] = {}
        self._tenant_running: dict[uuid.UUID, int] = collections.defaultdict(int)
        self._lock = threading.Lock()

    def set_tenant_limit(self, tenant_id: uuid.UUID, max_concurrent: int) -> None:
        with self._lock:
            self._tenant_limits[tenant_id] = max_concurrent

    def submit(self, backtest_run_id: uuid.UUID) -> bool:
        """Submit a backtest for execution.

        Returns True if accepted (under the tenant's quota) and queued for
        execution in a background thread; False if rejected.
        """
        db: Session = SessionLocal()
        try:
            run = db.get(BacktestRun, backtest_run_id)
            if run is None:
                logger.warning("Backtest run %s not found", backtest_run_id)
                return False

            tenant_id = run.tenant_id
            with self._lock:
                limit = self._tenant_limits.get(tenant_id, self._default_max_concurrent)
                if self._tenant_running[tenant_id] >= limit:
                    logger.info(
                        "Backtest %s rejected: tenant %s at quota %d",
                        backtest_run_id,
                        tenant_id,
                        limit,
                    )
                    return False
                self._tenant_running[tenant_id] += 1

            run.status = "RUNNING"
            db.commit()

            thread = threading.Thread(
                target=self._execute,
                args=(backtest_run_id,),
                daemon=True,
            )
            thread.start()
            return True
        finally:
            db.close()

    def _execute(self, backtest_run_id: uuid.UUID) -> None:
        """Run a backtest in a background thread and persist the result."""
        db: Session = SessionLocal()
        tenant_id: uuid.UUID | None = None
        try:
            run = db.get(BacktestRun, backtest_run_id)
            if run is None:
                logger.warning("Backtest run %s not found", backtest_run_id)
                return
            tenant_id = run.tenant_id
            try:
                metrics = run_backtest(db, run)
                run.status = "COMPLETED"
                run.metrics = metrics
            except Exception as exc:
                db.rollback()
                logger.exception("Backtest %s failed", backtest_run_id)
                run.status = "FAILED"
                run.error_message = str(exc)[:2000]
            db.commit()
        finally:
            if tenant_id is not None:
                with self._lock:
                    self._tenant_running[tenant_id] -= 1
            db.close()


backtest_scheduler = BacktestScheduler()
