import { useState, type FormEvent } from "react";
import { Link, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Pencil } from "lucide-react";
import { apiGet } from "../api/client";
import { getOrders } from "../api/orders";
import { getPortfolioDashboard, updatePortfolio } from "../api/portfolios";
import { useAuthStore } from "../stores/auth";
import { Badge } from "../components/ui/Badge";
import { Button } from "../components/ui/Button";
import { Card } from "../components/ui/Card";
import { Input } from "../components/ui/Input";
import { Modal } from "../components/ui/Modal";
import { Select } from "../components/ui/Select";
import { Spinner } from "../components/ui/Spinner";
import { StatCard } from "../components/ui/StatCard";
import {
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from "../components/ui/Table";
import type { PositionResponse } from "../types";

// Positions are fetched inline here (no position API is imported from
// ../api/orders): GET /api/tenants/:tenantId/portfolios/:portfolioId/positions
function getPortfolioPositions(
  tenantId: string,
  portfolioId: string,
): Promise<PositionResponse[]> {
  return apiGet<PositionResponse[]>(
    `/tenants/${tenantId}/portfolios/${portfolioId}/positions`,
  );
}

const currency = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

function tradingModeVariant(mode: string): "success" | "info" | "neutral" {
  if (mode === "LIVE") return "success";
  if (mode === "PAPER") return "info";
  return "neutral";
}

function riskStatusVariant(
  status: string,
): "success" | "warning" | "danger" | "neutral" {
  if (status === "OK") return "success";
  if (status === "WARNING") return "warning";
  if (status === "BREACHED" || status === "HALTED") return "danger";
  return "neutral";
}

function pnlClass(value: number): string {
  return clsx("font-medium", value >= 0 ? "text-profit" : "text-loss");
}

function formatPnl(value: number): string {
  return `${value >= 0 ? "+" : ""}${currency.format(value)}`;
}

export default function PortfolioDetailPage() {
  const { portfolioId } = useParams<{ portfolioId: string }>();
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [editOpen, setEditOpen] = useState(false);
  const [editName, setEditName] = useState("");
  const [editTradingMode, setEditTradingMode] = useState("PAPER");

  const enabled = tenantId !== null && portfolioId !== undefined;

  const dashboardQuery = useQuery({
    queryKey: ["portfolio-dashboard", tenantId, portfolioId],
    queryFn: () =>
      getPortfolioDashboard(tenantId as string, portfolioId as string),
    enabled,
  });

  const positionsQuery = useQuery({
    queryKey: ["portfolio-positions", tenantId, portfolioId],
    queryFn: () =>
      getPortfolioPositions(tenantId as string, portfolioId as string),
    enabled,
  });

  const ordersQuery = useQuery({
    queryKey: ["orders", tenantId, portfolioId],
    queryFn: () =>
      getOrders(tenantId as string, { portfolioId: portfolioId as string }),
    enabled,
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      updatePortfolio(tenantId as string, portfolioId as string, {
        name: editName.trim(),
        trading_mode: editTradingMode,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["portfolio-dashboard", tenantId, portfolioId],
      });
      void queryClient.invalidateQueries({
        queryKey: ["portfolios", tenantId],
      });
      setEditOpen(false);
    },
  });

  function openEditModal() {
    if (dashboardQuery.data) {
      setEditName(dashboardQuery.data.portfolio_name);
      setEditTradingMode(dashboardQuery.data.trading_mode);
    }
    setEditOpen(true);
  }

  function handleEditSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    updateMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <p className="text-sm text-slate-400">
          Select or create a tenant before viewing a portfolio.
        </p>
      </Card>
    );
  }

  if (dashboardQuery.isPending) {
    return (
      <div className="flex justify-center py-24 text-brand-400">
        <Spinner size="lg" />
      </div>
    );
  }

  if (dashboardQuery.isError) {
    return (
      <Card>
        <p className="text-sm text-loss">
          Failed to load portfolio: {dashboardQuery.error.message}
        </p>
      </Card>
    );
  }

  const dashboard = dashboardQuery.data;
  const positions = positionsQuery.data ?? [];
  const recentOrders = [...(ordersQuery.data ?? [])]
    .sort(
      (a, b) =>
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    )
    .slice(0, 10);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div>
            <p className="text-sm text-slate-400">
              <Link to="/portfolios" className="hover:text-brand-400">
                Portfolios
              </Link>{" "}
              / {dashboard.portfolio_name}
            </p>
            <div className="mt-1 flex items-center gap-3">
              <h1 className="text-2xl font-semibold text-slate-50">
                {dashboard.portfolio_name}
              </h1>
              <Badge variant={tradingModeVariant(dashboard.trading_mode)}>
                {dashboard.trading_mode}
              </Badge>
            </div>
          </div>
        </div>
        <Button variant="secondary" onClick={openEditModal}>
          <Pencil className="size-4" />
          Edit
        </Button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
        <StatCard
          label="Equity"
          value={currency.format(dashboard.current_equity)}
        />
        <StatCard label="Cash" value={currency.format(dashboard.cash)} />
        <StatCard
          label="Total P&L"
          value={
            <span className={pnlClass(dashboard.total_pnl)}>
              {formatPnl(dashboard.total_pnl)}
            </span>
          }
        />
        <StatCard
          label="Daily P&L"
          value={
            <span className={pnlClass(dashboard.daily_pnl)}>
              {formatPnl(dashboard.daily_pnl)}
            </span>
          }
        />
        <StatCard label="Positions" value={dashboard.positions_count} />
        <StatCard label="Open Orders" value={dashboard.open_orders_count} />
        <StatCard
          label="Risk Status"
          value={
            <Badge variant={riskStatusVariant(dashboard.risk_status)}>
              {dashboard.risk_status}
            </Badge>
          }
        />
      </div>

      <Card header="Positions">
        {positionsQuery.isPending ? (
          <div className="flex justify-center py-8 text-brand-400">
            <Spinner />
          </div>
        ) : positionsQuery.isError ? (
          <p className="text-sm text-loss">
            Failed to load positions: {positionsQuery.error.message}
          </p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Symbol</TableHead>
                <TableHead>Quantity</TableHead>
                <TableHead>Avg Entry Price</TableHead>
                <TableHead>Current Price</TableHead>
                <TableHead>Unrealized P&L</TableHead>
                <TableHead>Realized P&L</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {positions.length === 0 ? (
                <TableEmpty colSpan={6} message="No open positions" />
              ) : (
                positions.map((position) => (
                  <TableRow key={position.id}>
                    <TableCell className="font-medium">
                      {position.symbol}
                    </TableCell>
                    <TableCell>{position.quantity}</TableCell>
                    <TableCell>
                      {currency.format(position.avg_entry_price)}
                    </TableCell>
                    <TableCell>
                      {position.current_price !== null
                        ? currency.format(position.current_price)
                        : "—"}
                    </TableCell>
                    <TableCell
                      className={
                        position.unrealized_pnl !== null
                          ? pnlClass(position.unrealized_pnl)
                          : "text-slate-400"
                      }
                    >
                      {position.unrealized_pnl !== null
                        ? formatPnl(position.unrealized_pnl)
                        : "—"}
                    </TableCell>
                    <TableCell className={pnlClass(position.realized_pnl)}>
                      {formatPnl(position.realized_pnl)}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        )}
      </Card>

      <Card header="Recent Orders">
        {ordersQuery.isPending ? (
          <div className="flex justify-center py-8 text-brand-400">
            <Spinner />
          </div>
        ) : ordersQuery.isError ? (
          <p className="text-sm text-loss">
            Failed to load orders: {ordersQuery.error.message}
          </p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Symbol</TableHead>
                <TableHead>Side</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Quantity</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Price</TableHead>
                <TableHead>Created</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {recentOrders.length === 0 ? (
                <TableEmpty colSpan={7} message="No orders yet" />
              ) : (
                recentOrders.map((order) => (
                  <TableRow key={order.id}>
                    <TableCell className="font-medium">
                      {order.symbol}
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant={order.side === "BUY" ? "success" : "danger"}
                      >
                        {order.side}
                      </Badge>
                    </TableCell>
                    <TableCell>{order.order_type}</TableCell>
                    <TableCell>{order.quantity}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          order.status === "FILLED"
                            ? "success"
                            : order.status === "REJECTED" ||
                                order.status === "CANCELLED"
                              ? "danger"
                              : "info"
                        }
                      >
                        {order.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {order.price !== null
                        ? currency.format(order.price)
                        : "—"}
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(new Date(order.created_at), "MMM d, HH:mm")}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        )}
      </Card>

      <Modal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        title="Edit Portfolio"
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="edit-portfolio-form"
              loading={updateMutation.isPending}
            >
              Save
            </Button>
          </>
        }
      >
        <form
          id="edit-portfolio-form"
          onSubmit={handleEditSubmit}
          className="space-y-4"
        >
          <Input
            label="Name"
            required
            value={editName}
            onChange={(event) => setEditName(event.target.value)}
          />
          <Select
            label="Trading Mode"
            value={editTradingMode}
            onChange={(event) => setEditTradingMode(event.target.value)}
          >
            <option value="PAPER">PAPER</option>
            <option value="LIVE">LIVE</option>
          </Select>

          {updateMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {updateMutation.error.message}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
