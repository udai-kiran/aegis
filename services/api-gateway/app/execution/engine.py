"""Execution engine: order routing through broker accounts."""

from __future__ import annotations

import dataclasses
import logging
import uuid

from sqlalchemy.orm import Session

from app.broker.base import Broker, OrderRequest, OrderResult
from app.broker.credential_vault import decrypt_credentials
from app.broker.paper import PaperBroker
from app.broker.zerodha import ZerodhaBroker
from app.models import BrokerAccount, Order, Portfolio, Position, Tenant
from app.risk.evaluator import RiskDecision, RiskEvaluator

logger = logging.getLogger(__name__)


def _resolve_broker(db: Session, broker_account: BrokerAccount) -> Broker:
    """Instantiate the broker adapter for a broker account."""
    if broker_account.broker_type == "ZERODHA":
        credentials = None
        if broker_account.encrypted_credentials:
            credentials = decrypt_credentials(broker_account.encrypted_credentials)
        return ZerodhaBroker(db, credentials)
    if broker_account.broker_type == "PAPER":
        return PaperBroker(db)
    raise ValueError(f"Unsupported broker type: {broker_account.broker_type}")


class ExecutionEngine:
    """Routes orders through a tenant's broker account with risk checks."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def execute(
        self,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        broker_account_id: uuid.UUID,
        symbol: str,
        exchange: str,
        side: str,
        order_type: str,
        quantity: float,
        price: float | None = None,
    ) -> Order:
        """Validate, risk-check, route, and record an order. Returns the Order."""
        broker_account = (
            self.db.query(BrokerAccount)
            .filter(BrokerAccount.id == broker_account_id)
            .first()
        )
        if broker_account is None:
            raise ValueError(f"Broker account {broker_account_id} not found")
        if broker_account.tenant_id != tenant_id:
            raise ValueError("Broker account does not belong to tenant")
        if broker_account.status != "ACTIVE":
            raise ValueError(
                f"Broker account status is {broker_account.status}, expected ACTIVE"
            )

        tenant = self.db.query(Tenant).filter(Tenant.id == tenant_id).first()
        if tenant is None:
            raise ValueError(f"Tenant {tenant_id} not found")

        portfolio = (
            self.db.query(Portfolio)
            .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
            .first()
        )
        if portfolio is None:
            raise ValueError(
                f"Portfolio {portfolio_id} not found for tenant {tenant_id}"
            )
        if portfolio.trading_mode == "PAPER":
            raise ValueError("Cannot execute through broker on a PAPER portfolio")

        halt_reason = self._check_kill_switches(tenant, portfolio, broker_account)
        if halt_reason is not None:
            logger.warning("Order blocked by kill switch: %s", halt_reason)
            raise ValueError(halt_reason)

        evaluator = RiskEvaluator(self.db)
        decision = evaluator.evaluate_order(
            tenant_id, portfolio_id, symbol, side, quantity, price or 0.0
        )
        risk_decision = self._risk_decision_dict(decision)

        if decision.approved_quantity <= 0:
            order = Order(
                tenant_id=tenant_id,
                portfolio_id=portfolio_id,
                symbol=symbol,
                exchange=exchange,
                side=side,
                order_type=order_type,
                quantity=quantity,
                price=price,
                status="REJECTED",
                reject_reason=decision.reason,
                source=broker_account.broker_type,
                broker_account_id=broker_account.id,
                risk_decision=risk_decision,
            )
            self.db.add(order)
            self.db.flush()
            logger.info("Order %s rejected by risk: %s", order.id, decision.reason)
            return order

        broker = _resolve_broker(self.db, broker_account)
        request = OrderRequest(
            tenant_id=tenant_id,
            portfolio_id=portfolio_id,
            symbol=symbol,
            side=side,
            quantity=decision.approved_quantity,
            exchange=exchange,
            order_type=order_type,
            price=price,
        )
        result: OrderResult = broker.place_order(request)

        order = Order(
            tenant_id=tenant_id,
            portfolio_id=portfolio_id,
            symbol=symbol,
            exchange=exchange,
            side=side,
            order_type=order_type,
            quantity=decision.approved_quantity,
            price=price,
            status=result.status,
            filled_quantity=result.filled_quantity,
            avg_fill_price=result.avg_fill_price,
            reject_reason=result.reject_reason,
            source=broker_account.broker_type,
            broker_account_id=broker_account.id,
            risk_decision=risk_decision,
        )
        self.db.add(order)

        if result.status == "FILLED":
            self._apply_fill(
                tenant_id,
                portfolio_id,
                symbol,
                exchange,
                side,
                result.filled_quantity,
                result.avg_fill_price,
            )

        self.db.flush()
        logger.info(
            "Order %s: %s %s qty=%s status=%s",
            order.id,
            side,
            symbol,
            decision.approved_quantity,
            result.status,
        )
        return order

    def _apply_fill(
        self,
        tenant_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        symbol: str,
        exchange: str,
        side: str,
        filled_qty: float,
        fill_price: float,
    ) -> None:
        """Update or create the position for this fill and adjust portfolio cash/equity."""
        portfolio = (
            self.db.query(Portfolio)
            .filter(Portfolio.id == portfolio_id, Portfolio.tenant_id == tenant_id)
            .first()
        )
        if portfolio is None:
            raise ValueError(f"Portfolio {portfolio_id} not found")

        position = (
            self.db.query(Position)
            .filter(
                Position.portfolio_id == portfolio.id,
                Position.tenant_id == portfolio.tenant_id,
                Position.symbol == symbol,
                Position.exchange == exchange,
            )
            .first()
        )

        if position is not None:
            if side == "BUY":
                new_qty = float(position.quantity) + filled_qty
                if new_qty > 0:
                    position.avg_entry_price = (
                        float(position.avg_entry_price) * float(position.quantity)
                        + fill_price * filled_qty
                    ) / new_qty
                    position.quantity = new_qty
            else:  # SELL
                new_qty = float(position.quantity) - filled_qty
                if new_qty <= 0:
                    position.realized_pnl = float(
                        position.realized_pnl
                    ) + filled_qty * (fill_price - float(position.avg_entry_price))
                    self.db.delete(position)
                    position = None
                else:
                    position.realized_pnl = float(
                        position.realized_pnl
                    ) + filled_qty * (fill_price - float(position.avg_entry_price))
                    position.quantity = new_qty

            if position is not None:
                position.current_price = fill_price
        elif side == "BUY":
            position = Position(
                tenant_id=portfolio.tenant_id,
                portfolio_id=portfolio.id,
                symbol=symbol,
                exchange=exchange,
                quantity=filled_qty,
                avg_entry_price=fill_price,
                current_price=fill_price,
            )
            self.db.add(position)

        trade_value = filled_qty * fill_price
        if side == "BUY":
            portfolio.cash = float(portfolio.cash) - trade_value
        else:
            portfolio.cash = float(portfolio.cash) + trade_value

        self.db.flush()

        positions = (
            self.db.query(Position)
            .filter(
                Position.portfolio_id == portfolio.id,
                Position.tenant_id == portfolio.tenant_id,
            )
            .all()
        )
        positions_value = sum(
            float(p.quantity) * float(p.current_price)
            for p in positions
            if p.current_price is not None
        )
        portfolio.current_equity = float(portfolio.cash) + positions_value

    @staticmethod
    def _check_kill_switches(
        tenant: Tenant, portfolio: Portfolio, broker_account: BrokerAccount
    ) -> str | None:
        """Return a halt reason if any kill switch is active, else None."""
        if tenant.trading_halted:
            return "Trading halted at tenant level"
        if portfolio.trading_halted:
            return f"Trading halted for portfolio {portfolio.id}"
        if broker_account.status == "HALTED":
            return f"Broker account {broker_account.id} is halted"
        return None

    @staticmethod
    def _risk_decision_dict(decision: RiskDecision) -> dict:
        data = dataclasses.asdict(decision)
        data["status"] = decision.status.value
        data["policy_id"] = str(decision.policy_id) if decision.policy_id else None
        return data
