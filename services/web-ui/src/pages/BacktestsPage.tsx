import { Fragment, useState, type FormEvent, type ReactNode } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { ChevronDown, ChevronRight, Plus } from "lucide-react";
import { createBacktest, getBacktests } from "../api/backtests";
import { getStrategies, getStrategyConfigs } from "../api/strategies";
import { useAuthStore } from "../stores/auth";
import type { BacktestResponse } from "../types";
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

const statusVariant: Record<string, BadgeVariant> = {
  PENDING: "neutral",
  RUNNING: "info",
  COMPLETED: "success",
  FAILED: "danger",
};

function metric(
  metrics: Record<string, unknown> | null,
  ...keys: string[]
): number | null {
  if (!metrics) return null;
  for (const key of keys) {
    const value = metrics[key];
    if (typeof value === "number") return value;
  }
  return null;
}

function pct(value: number | null): string {
  if (value === null) return "—";
  return `${(value * 100).toFixed(2)}%`;
}

function num(value: number | null): string {
  if (value === null) return "—";
  return value.toFixed(2);
}

function MetricCard({
  label,
  value,
  valueClassName,
}: {
  label: string;
  value: ReactNode;
  valueClassName?: string | undefined;
}) {
  return (
    <div className="rounded-md border border-surface-3 bg-surface-2 p-3">
      <p className="text-xs text-slate-400">{label}</p>
      <p
        className={clsx(
          "mt-1 text-sm font-semibold text-slate-50",
          valueClassName,
        )}
      >
        {value}
      </p>
    </div>
  );
}

function BacktestDetail({ backtest }: { backtest: BacktestResponse }) {
  if (backtest.status === "FAILED") {
    return (
      <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
        {backtest.error_message ?? "Backtest failed"}
      </p>
    );
  }
  if (backtest.status !== "COMPLETED") {
    return (
      <p className="text-sm text-slate-400">
        Metrics will appear here once the backtest completes.
      </p>
    );
  }
  const metrics = backtest.metrics;
  const totalReturn = metric(metrics, "total_return", "net_return");
  const sharpe = metric(metrics, "sharpe_ratio", "sharpe");
  const maxDrawdown = metric(metrics, "max_drawdown");
  const winRate = metric(metrics, "win_rate");
  const totalTrades = metric(metrics, "total_trades");
  const avgTradeReturn = metric(metrics, "avg_trade_return", "expected_value");

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
      <MetricCard
        label="Total Return"
        value={pct(totalReturn)}
        valueClassName={
          totalReturn === null
            ? undefined
            : totalReturn >= 0
              ? "text-profit"
              : "text-loss"
        }
      />
      <MetricCard label="Sharpe Ratio" value={num(sharpe)} />
      <MetricCard
        label="Max Drawdown"
        value={pct(maxDrawdown)}
        valueClassName="text-loss"
      />
      <MetricCard label="Win Rate" value={pct(winRate)} />
      <MetricCard
        label="Total Trades"
        value={totalTrades === null ? "—" : totalTrades}
      />
      <MetricCard
        label="Avg Trade Return"
        value={pct(avgTradeReturn)}
        valueClassName={
          avgTradeReturn === null
            ? undefined
            : avgTradeReturn >= 0
              ? "text-profit"
              : "text-loss"
        }
      />
    </div>
  );
}

export default function BacktestsPage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [modalOpen, setModalOpen] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [strategyConfigId, setStrategyConfigId] = useState("");
  const [symbol, setSymbol] = useState("");
  const [exchange, setExchange] = useState("NSE");
  const [timeframe, setTimeframe] = useState("1d");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");

  const backtestsQuery = useQuery({
    queryKey: ["backtests", tenantId],
    queryFn: () => getBacktests(tenantId as string),
    enabled: tenantId !== null,
  });

  const configsQuery = useQuery({
    queryKey: ["strategy-configs", tenantId],
    queryFn: () => getStrategyConfigs(tenantId as string),
    enabled: tenantId !== null,
  });

  const strategiesQuery = useQuery({
    queryKey: ["strategies", tenantId],
    queryFn: () => getStrategies(tenantId as string),
    enabled: tenantId !== null,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      createBacktest(tenantId as string, {
        strategy_config_id: strategyConfigId,
        symbol: symbol.trim(),
        ...(exchange.trim() ? { exchange: exchange.trim() } : {}),
        ...(timeframe.trim() ? { timeframe: timeframe.trim() } : {}),
        start_date: startDate,
        end_date: endDate,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["backtests", tenantId] });
      setModalOpen(false);
      setStrategyConfigId("");
      setSymbol("");
      setExchange("NSE");
      setTimeframe("1d");
      setStartDate("");
      setEndDate("");
    },
  });

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    createMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant before running backtests."
        />
      </Card>
    );
  }

  const backtests = backtestsQuery.data ?? [];
  const configs = configsQuery.data ?? [];
  const strategies = strategiesQuery.data ?? [];

  const strategyName = (id: string): string =>
    strategies.find((s) => s.id === id)?.name ?? `${id.slice(0, 8)}…`;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50">Backtests</h1>
          <p className="mt-1 text-sm text-slate-400">
            Run and review strategy backtests
          </p>
        </div>
        <Button onClick={() => setModalOpen(true)}>
          <Plus className="size-4" />
          Run Backtest
        </Button>
      </div>

      {backtestsQuery.isPending ? (
        <div className="flex justify-center py-24 text-brand-400">
          <Spinner size="lg" />
        </div>
      ) : backtestsQuery.isError ? (
        <Card>
          <p className="text-sm text-loss">
            Failed to load backtests: {backtestsQuery.error.message}
          </p>
        </Card>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-8" />
              <TableHead>Symbol</TableHead>
              <TableHead>Exchange</TableHead>
              <TableHead>Timeframe</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Start Date</TableHead>
              <TableHead>End Date</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {backtests.length === 0 ? (
              <TableEmpty
                colSpan={8}
                message="No backtests yet. Run one to get started."
              />
            ) : (
              backtests.map((backtest) => {
                const expanded = expandedId === backtest.id;
                return (
                  <Fragment key={backtest.id}>
                    <TableRow
                      onClick={() =>
                        setExpandedId(expanded ? null : backtest.id)
                      }
                      className="cursor-pointer"
                    >
                      <TableCell className="text-slate-400">
                        {expanded ? (
                          <ChevronDown className="size-4" />
                        ) : (
                          <ChevronRight className="size-4" />
                        )}
                      </TableCell>
                      <TableCell className="font-medium">
                        {backtest.symbol}
                      </TableCell>
                      <TableCell>{backtest.exchange}</TableCell>
                      <TableCell className="text-slate-400">
                        {backtest.timeframe}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={statusVariant[backtest.status] ?? "neutral"}
                        >
                          {backtest.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {format(new Date(backtest.start_date), "MMM d, yyyy")}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {format(new Date(backtest.end_date), "MMM d, yyyy")}
                      </TableCell>
                      <TableCell className="text-slate-400">
                        {format(new Date(backtest.created_at), "MMM d, yyyy")}
                      </TableCell>
                    </TableRow>
                    {expanded && (
                      <TableRow className="hover:bg-transparent">
                        <TableCell colSpan={8} className="bg-surface-2/40">
                          <BacktestDetail backtest={backtest} />
                        </TableCell>
                      </TableRow>
                    )}
                  </Fragment>
                );
              })
            )}
          </TableBody>
        </Table>
      )}

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title="Run Backtest"
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="run-backtest-form"
              loading={createMutation.isPending}
            >
              Run
            </Button>
          </>
        }
      >
        <form
          id="run-backtest-form"
          onSubmit={handleSubmit}
          className="space-y-4"
        >
          <Select
            label="Strategy Config"
            required
            value={strategyConfigId}
            onChange={(event) => setStrategyConfigId(event.target.value)}
          >
            <option value="" disabled>
              Select a strategy config
            </option>
            {configs.map((config) => (
              <option key={config.id} value={config.id}>
                {strategyName(config.strategy_id)} ({config.id.slice(0, 8)}…)
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
          <Input
            label="Timeframe"
            value={timeframe}
            onChange={(event) => setTimeframe(event.target.value)}
            placeholder="1d"
          />
          <Input
            label="Start Date"
            type="date"
            required
            value={startDate}
            onChange={(event) => setStartDate(event.target.value)}
          />
          <Input
            label="End Date"
            type="date"
            required
            value={endDate}
            onChange={(event) => setEndDate(event.target.value)}
          />

          {createMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createMutation.error.message}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
