import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Plus } from "lucide-react";
import { getOrders, submitPaperOrder } from "../api/orders";
import { getPortfolios } from "../api/portfolios";
import { useAuthStore } from "../stores/auth";
import type { OrderResponse } from "../types";
import { Badge } from "../components/ui/Badge";
import { Button } from "../components/ui/Button";
import { Card } from "../components/ui/Card";
import { EmptyState } from "../components/ui/EmptyState";
import { Input } from "../components/ui/Input";
import { Modal } from "../components/ui/Modal";
import { Select } from "../components/ui/Select";
import { Spinner } from "../components/ui/Spinner";
import {
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from "../components/ui/Table";

type BadgeVariant = "success" | "warning" | "danger" | "info" | "neutral";
type Tab = "live" | "paper";

const tabs: { id: Tab; label: string }[] = [
  { id: "live", label: "Live Orders" },
  { id: "paper", label: "Paper Orders" },
];

const orderStatuses = [
  "NEW",
  "SUBMITTED",
  "ACKNOWLEDGED",
  "PARTIALLY_FILLED",
  "FILLED",
  "REJECTED",
  "CANCELLED",
  "FAILED",
];

const statusVariant: Record<string, BadgeVariant> = {
  NEW: "neutral",
  SUBMITTED: "info",
  ACKNOWLEDGED: "info",
  PARTIALLY_FILLED: "warning",
  FILLED: "success",
  REJECTED: "danger",
  CANCELLED: "neutral",
  FAILED: "danger",
};

function price(value: number | null): string {
  if (value === null) return "—";
  return value.toFixed(2);
}

function OrdersTable({
  orders,
  emptyMessage,
}: {
  orders: OrderResponse[];
  emptyMessage: string;
}) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Symbol</TableHead>
          <TableHead>Side</TableHead>
          <TableHead>Type</TableHead>
          <TableHead>Quantity</TableHead>
          <TableHead>Price</TableHead>
          <TableHead>Filled Qty</TableHead>
          <TableHead>Avg Fill Price</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Source</TableHead>
          <TableHead>Created</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {orders.length === 0 ? (
          <TableEmpty colSpan={10} message={emptyMessage} />
        ) : (
          orders.map((order) => (
            <TableRow key={order.id}>
              <TableCell className="font-medium">{order.symbol}</TableCell>
              <TableCell>
                <Badge variant={order.side === "BUY" ? "success" : "danger"}>
                  {order.side}
                </Badge>
              </TableCell>
              <TableCell>{order.order_type}</TableCell>
              <TableCell>{order.quantity}</TableCell>
              <TableCell>{price(order.price)}</TableCell>
              <TableCell>{order.filled_quantity}</TableCell>
              <TableCell>{price(order.avg_fill_price)}</TableCell>
              <TableCell>
                <Badge variant={statusVariant[order.status] ?? "neutral"}>
                  {order.status}
                </Badge>
              </TableCell>
              <TableCell className="text-slate-400">{order.source}</TableCell>
              <TableCell className="text-slate-400">
                {format(new Date(order.created_at), "MMM d, yyyy HH:mm")}
              </TableCell>
            </TableRow>
          ))
        )}
      </TableBody>
    </Table>
  );
}

export default function OrdersPage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [tab, setTab] = useState<Tab>("live");
  const [statusFilter, setStatusFilter] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [portfolioId, setPortfolioId] = useState("");
  const [symbol, setSymbol] = useState("");
  const [exchange, setExchange] = useState("NSE");
  const [side, setSide] = useState("BUY");
  const [orderType, setOrderType] = useState("MARKET");
  const [quantity, setQuantity] = useState("");
  const [priceValue, setPriceValue] = useState("");

  const ordersQuery = useQuery({
    queryKey: ["orders", tenantId],
    queryFn: () => getOrders(tenantId as string),
    enabled: tenantId !== null,
  });

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const paperOrderMutation = useMutation({
    mutationFn: () =>
      submitPaperOrder(tenantId as string, {
        portfolio_id: portfolioId,
        symbol: symbol.trim(),
        ...(exchange.trim() ? { exchange: exchange.trim() } : {}),
        side,
        order_type: orderType,
        quantity: Number(quantity),
        ...(orderType === "LIMIT" && priceValue
          ? { price: Number(priceValue) }
          : {}),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["orders", tenantId] });
      setModalOpen(false);
      setPortfolioId("");
      setSymbol("");
      setExchange("NSE");
      setSide("BUY");
      setOrderType("MARKET");
      setQuantity("");
      setPriceValue("");
    },
  });

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    paperOrderMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant before viewing orders."
        />
      </Card>
    );
  }

  const orders = ordersQuery.data ?? [];
  const portfolios = portfoliosQuery.data ?? [];

  const liveOrders = orders.filter(
    (order) =>
      order.source !== "PAPER" &&
      (statusFilter === "" || order.status === statusFilter),
  );
  const paperOrders = orders.filter((order) => order.source === "PAPER");

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-800">Orders</h1>
          <p className="mt-1 text-sm text-slate-400">
            View live orders and place paper trades
          </p>
        </div>
        {tab === "paper" && (
          <Button onClick={() => setModalOpen(true)}>
            <Plus className="size-4" />
            Place Paper Order
          </Button>
        )}
      </div>

      <div className="flex gap-1 border-b border-surface-3">
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setTab(item.id)}
            className={clsx(
              "-mb-px border-b-2 px-4 py-2 text-sm font-medium transition-colors",
              tab === item.id
                ? "border-brand-600 text-brand-700"
                : "border-transparent text-slate-500 hover:text-slate-900",
            )}
          >
            {item.label}
          </button>
        ))}
      </div>

      {tab === "live" && (
        <div className="w-56">
          <Select
            label="Filter by status"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
          >
            <option value="">All statuses</option>
            {orderStatuses.map((status) => (
              <option key={status} value={status}>
                {status}
              </option>
            ))}
          </Select>
        </div>
      )}

      {ordersQuery.isPending ? (
        <div className="flex justify-center py-24 text-brand-600">
          <Spinner size="lg" />
        </div>
      ) : ordersQuery.isError ? (
        <Card>
          <p className="text-sm text-loss">
            Failed to load orders: {ordersQuery.error.message}
          </p>
        </Card>
      ) : tab === "live" ? (
        <OrdersTable
          orders={liveOrders}
          emptyMessage="No live orders match the current filter."
        />
      ) : (
        <OrdersTable
          orders={paperOrders}
          emptyMessage="No paper orders yet. Place one to get started."
        />
      )}

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title="Place Paper Order"
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="paper-order-form"
              loading={paperOrderMutation.isPending}
            >
              Place Order
            </Button>
          </>
        }
      >
        <form
          id="paper-order-form"
          onSubmit={handleSubmit}
          className="space-y-4"
        >
          <Select
            label="Portfolio"
            required
            value={portfolioId}
            onChange={(event) => setPortfolioId(event.target.value)}
          >
            <option value="" disabled>
              Select a portfolio
            </option>
            {portfolios.map((portfolio) => (
              <option key={portfolio.id} value={portfolio.id}>
                {portfolio.name}
              </option>
            ))}
          </Select>
          <Input
            label="Symbol"
            required
            value={symbol}
            onChange={(event) => setSymbol(event.target.value)}
            placeholder="RELIANCE"
          />
          <Input
            label="Exchange"
            value={exchange}
            onChange={(event) => setExchange(event.target.value)}
            placeholder="NSE"
          />
          <Select
            label="Side"
            value={side}
            onChange={(event) => setSide(event.target.value)}
          >
            <option value="BUY">BUY</option>
            <option value="SELL">SELL</option>
          </Select>
          <Select
            label="Order Type"
            value={orderType}
            onChange={(event) => setOrderType(event.target.value)}
          >
            <option value="MARKET">MARKET</option>
            <option value="LIMIT">LIMIT</option>
          </Select>
          <Input
            label="Quantity"
            type="number"
            required
            min="0"
            step="any"
            value={quantity}
            onChange={(event) => setQuantity(event.target.value)}
          />
          {orderType === "LIMIT" && (
            <Input
              label="Price"
              type="number"
              required
              min="0"
              step="any"
              value={priceValue}
              onChange={(event) => setPriceValue(event.target.value)}
            />
          )}

          {paperOrderMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {paperOrderMutation.error.message}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
