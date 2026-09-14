import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Plus } from "lucide-react";
import {
  createStrategy,
  createStrategyConfig,
  evaluateStrategyHealth,
  getStrategies,
  getStrategyConfigs,
  getStrategyHealthScores,
  updateStrategy,
} from "../api/strategies";
import { getPortfolios } from "../api/portfolios";
import { useAuthStore } from "../stores/auth";
import type { StrategyResponse } from "../types";
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
type Tab = "strategies" | "configs" | "health";

const tabs: { id: Tab; label: string }[] = [
  { id: "strategies", label: "Strategies" },
  { id: "configs", label: "Strategy Configs" },
  { id: "health", label: "Strategy Health" },
];

const lifecycleVariant: Record<string, BadgeVariant> = {
  BACKTEST: "info",
  PAPER: "warning",
  LIVE: "success",
  RETIRED: "danger",
};

const healthVariant: Record<string, BadgeVariant> = {
  HEALTHY: "success",
  WARNING: "warning",
  DEGRADED: "danger",
  CRITICAL: "danger",
};

function pct(value: number | null): string {
  if (value === null) return "—";
  return `${(value * 100).toFixed(2)}%`;
}

function num(value: number | null): string {
  if (value === null) return "—";
  return value.toFixed(2);
}

export default function StrategiesPage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [tab, setTab] = useState<Tab>("strategies");

  // Create strategy form
  const [strategyModalOpen, setStrategyModalOpen] = useState(false);
  const [name, setName] = useState("");
  const [strategyType, setStrategyType] = useState("momentum");
  const [version, setVersion] = useState("1.0.0");
  const [description, setDescription] = useState("");

  // Create config form
  const [configModalOpen, setConfigModalOpen] = useState(false);
  const [configStrategyId, setConfigStrategyId] = useState("");
  const [configPortfolioId, setConfigPortfolioId] = useState("");
  const [parameters, setParameters] = useState("{}");
  const [parametersError, setParametersError] = useState<string | null>(null);

  // Evaluate health form
  const [healthModalOpen, setHealthModalOpen] = useState(false);
  const [healthConfigId, setHealthConfigId] = useState("");
  const [healthPortfolioId, setHealthPortfolioId] = useState("");

  const strategiesQuery = useQuery({
    queryKey: ["strategies", tenantId],
    queryFn: () => getStrategies(tenantId as string),
    enabled: tenantId !== null,
  });

  const configsQuery = useQuery({
    queryKey: ["strategy-configs", tenantId],
    queryFn: () => getStrategyConfigs(tenantId as string),
    enabled: tenantId !== null,
  });

  const healthQuery = useQuery({
    queryKey: ["strategy-health", tenantId],
    queryFn: () => getStrategyHealthScores(tenantId as string),
    enabled: tenantId !== null,
  });

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const createStrategyMutation = useMutation({
    mutationFn: () =>
      createStrategy(tenantId as string, {
        name: name.trim(),
        strategy_type: strategyType,
        version: version.trim(),
        ...(description.trim() ? { description: description.trim() } : {}),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["strategies", tenantId],
      });
      setStrategyModalOpen(false);
      setName("");
      setStrategyType("momentum");
      setVersion("1.0.0");
      setDescription("");
    },
  });

  const toggleActiveMutation = useMutation({
    mutationFn: (strategy: StrategyResponse) =>
      updateStrategy(tenantId as string, strategy.id, {
        is_active: !strategy.is_active,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["strategies", tenantId],
      });
    },
  });

  const createConfigMutation = useMutation({
    mutationFn: (parsedParameters: Record<string, unknown>) =>
      createStrategyConfig(tenantId as string, {
        strategy_id: configStrategyId,
        portfolio_id: configPortfolioId,
        parameters: parsedParameters,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["strategy-configs", tenantId],
      });
      setConfigModalOpen(false);
      setConfigStrategyId("");
      setConfigPortfolioId("");
      setParameters("{}");
      setParametersError(null);
    },
  });

  const evaluateHealthMutation = useMutation({
    mutationFn: () =>
      evaluateStrategyHealth(tenantId as string, {
        strategy_config_id: healthConfigId,
        portfolio_id: healthPortfolioId,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["strategy-health", tenantId],
      });
      setHealthModalOpen(false);
      setHealthConfigId("");
      setHealthPortfolioId("");
    },
  });

  function handleCreateStrategy(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    createStrategyMutation.mutate();
  }

  function handleCreateConfig(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    let parsed: Record<string, unknown>;
    try {
      const value: unknown = JSON.parse(parameters);
      if (typeof value !== "object" || value === null || Array.isArray(value)) {
        setParametersError("Parameters must be a JSON object");
        return;
      }
      parsed = value as Record<string, unknown>;
    } catch {
      setParametersError("Invalid JSON");
      return;
    }
    setParametersError(null);
    createConfigMutation.mutate(parsed);
  }

  function handleEvaluateHealth(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    evaluateHealthMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant before managing strategies."
        />
      </Card>
    );
  }

  const strategies = strategiesQuery.data ?? [];
  const configs = configsQuery.data ?? [];
  const healthScores = healthQuery.data ?? [];
  const portfolios = portfoliosQuery.data ?? [];

  const strategyName = (id: string): string =>
    strategies.find((s) => s.id === id)?.name ?? `${id.slice(0, 8)}…`;
  const portfolioName = (id: string): string =>
    portfolios.find((p) => p.id === id)?.name ?? `${id.slice(0, 8)}…`;

  const isPending =
    (tab === "strategies" && strategiesQuery.isPending) ||
    (tab === "configs" && configsQuery.isPending) ||
    (tab === "health" && healthQuery.isPending);
  const activeError =
    tab === "strategies"
      ? strategiesQuery.error
      : tab === "configs"
        ? configsQuery.error
        : healthQuery.error;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-800">Strategies</h1>
          <p className="mt-1 text-sm text-slate-400">
            Manage strategies, configurations, and health
          </p>
        </div>
        {tab === "strategies" && (
          <Button onClick={() => setStrategyModalOpen(true)}>
            <Plus className="size-4" />
            Create Strategy
          </Button>
        )}
        {tab === "configs" && (
          <Button onClick={() => setConfigModalOpen(true)}>
            <Plus className="size-4" />
            Create Config
          </Button>
        )}
        {tab === "health" && (
          <Button onClick={() => setHealthModalOpen(true)}>
            <Plus className="size-4" />
            Evaluate Health
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

      {isPending ? (
        <div className="flex justify-center py-24 text-brand-600">
          <Spinner size="lg" />
        </div>
      ) : activeError ? (
        <Card>
          <p className="text-sm text-loss">
            Failed to load data: {activeError.message}
          </p>
        </Card>
      ) : tab === "strategies" ? (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Version</TableHead>
              <TableHead>Active</TableHead>
              <TableHead>Description</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {strategies.length === 0 ? (
              <TableEmpty
                colSpan={6}
                message="No strategies yet. Create one to get started."
              />
            ) : (
              strategies.map((strategy) => (
                <TableRow key={strategy.id}>
                  <TableCell className="font-medium">{strategy.name}</TableCell>
                  <TableCell>{strategy.strategy_type}</TableCell>
                  <TableCell className="text-slate-400">
                    {strategy.version}
                  </TableCell>
                  <TableCell>
                    <button
                      type="button"
                      onClick={() => toggleActiveMutation.mutate(strategy)}
                      disabled={toggleActiveMutation.isPending}
                      title="Click to toggle active status"
                      className="cursor-pointer disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      <Badge
                        variant={strategy.is_active ? "success" : "danger"}
                      >
                        {strategy.is_active ? "Active" : "Inactive"}
                      </Badge>
                    </button>
                  </TableCell>
                  <TableCell className="max-w-xs truncate text-slate-400">
                    {strategy.description ?? "—"}
                  </TableCell>
                  <TableCell className="text-slate-400">
                    {format(new Date(strategy.created_at), "MMM d, yyyy")}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      ) : tab === "configs" ? (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Strategy</TableHead>
              <TableHead>Portfolio</TableHead>
              <TableHead>Parameters</TableHead>
              <TableHead>Lifecycle Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {configs.length === 0 ? (
              <TableEmpty
                colSpan={5}
                message="No strategy configs yet. Create one to get started."
              />
            ) : (
              configs.map((config) => (
                <TableRow key={config.id}>
                  <TableCell className="font-medium">
                    {strategyName(config.strategy_id)}
                  </TableCell>
                  <TableCell>{portfolioName(config.portfolio_id)}</TableCell>
                  <TableCell className="max-w-xs truncate text-slate-400">
                    <code title={JSON.stringify(config.parameters)}>
                      {JSON.stringify(config.parameters)}
                    </code>
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={
                        lifecycleVariant[config.lifecycle_status] ?? "neutral"
                      }
                    >
                      {config.lifecycle_status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-slate-400">
                    {format(new Date(config.created_at), "MMM d, yyyy")}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Strategy Config</TableHead>
              <TableHead>Win Rate</TableHead>
              <TableHead>Avg Return</TableHead>
              <TableHead>Sharpe</TableHead>
              <TableHead>Max Drawdown</TableHead>
              <TableHead>Health Score</TableHead>
              <TableHead>Health Status</TableHead>
              <TableHead>Evaluated At</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {healthScores.length === 0 ? (
              <TableEmpty
                colSpan={8}
                message="No health evaluations yet. Run one to get started."
              />
            ) : (
              healthScores.map((health) => {
                const config = configs.find(
                  (c) => c.id === health.strategy_config_id,
                );
                return (
                  <TableRow key={health.id}>
                    <TableCell className="font-medium">
                      {config
                        ? `${strategyName(config.strategy_id)} · ${portfolioName(config.portfolio_id)}`
                        : `${health.strategy_config_id.slice(0, 8)}…`}
                    </TableCell>
                    <TableCell>{pct(health.win_rate)}</TableCell>
                    <TableCell
                      className={clsx(
                        health.avg_return >= 0 ? "text-profit" : "text-loss",
                      )}
                    >
                      {pct(health.avg_return)}
                    </TableCell>
                    <TableCell>{num(health.sharpe_ratio)}</TableCell>
                    <TableCell className="text-loss">
                      {pct(health.max_drawdown)}
                    </TableCell>
                    <TableCell>{health.health_score.toFixed(1)}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          healthVariant[health.health_status] ?? "neutral"
                        }
                      >
                        {health.health_status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(
                        new Date(health.evaluated_at),
                        "MMM d, yyyy HH:mm",
                      )}
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      )}

      <Modal
        open={strategyModalOpen}
        onClose={() => setStrategyModalOpen(false)}
        title="Create Strategy"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setStrategyModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-strategy-form"
              loading={createStrategyMutation.isPending}
            >
              Create
            </Button>
          </>
        }
      >
        <form
          id="create-strategy-form"
          onSubmit={handleCreateStrategy}
          className="space-y-4"
        >
          <Input
            label="Name"
            required
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Momentum Breakout"
          />
          <Select
            label="Strategy Type"
            value={strategyType}
            onChange={(event) => setStrategyType(event.target.value)}
          >
            <option value="momentum">momentum</option>
            <option value="mean_reversion">mean_reversion</option>
          </Select>
          <Input
            label="Version"
            required
            value={version}
            onChange={(event) => setVersion(event.target.value)}
            placeholder="1.0.0"
          />
          <Input
            label="Description"
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            placeholder="Optional description"
          />

          {createStrategyMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createStrategyMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={configModalOpen}
        onClose={() => setConfigModalOpen(false)}
        title="Create Strategy Config"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setConfigModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-config-form"
              loading={createConfigMutation.isPending}
            >
              Create
            </Button>
          </>
        }
      >
        <form
          id="create-config-form"
          onSubmit={handleCreateConfig}
          className="space-y-4"
        >
          <Select
            label="Strategy"
            required
            value={configStrategyId}
            onChange={(event) => setConfigStrategyId(event.target.value)}
          >
            <option value="" disabled>
              Select a strategy
            </option>
            {strategies.map((strategy) => (
              <option key={strategy.id} value={strategy.id}>
                {strategy.name} (v{strategy.version})
              </option>
            ))}
          </Select>
          <Select
            label="Portfolio"
            required
            value={configPortfolioId}
            onChange={(event) => setConfigPortfolioId(event.target.value)}
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
          <div className="w-full">
            <label
              htmlFor="config-parameters"
              className="mb-1 block text-sm text-slate-600"
            >
              Parameters (JSON)
            </label>
            <textarea
              id="config-parameters"
              rows={5}
              value={parameters}
              onChange={(event) => setParameters(event.target.value)}
              spellCheck={false}
              className={clsx(
                "w-full rounded-md border bg-surface-2 px-3 py-2 font-mono text-sm text-slate-800 placeholder-slate-500",
                "focus:outline-none focus:ring-1",
                parametersError
                  ? "border-loss focus:border-loss focus:ring-loss"
                  : "border-surface-3 focus:border-brand-500 focus:ring-brand-500",
              )}
            />
            {parametersError && (
              <p className="mt-1 text-xs text-loss">{parametersError}</p>
            )}
          </div>

          {createConfigMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createConfigMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={healthModalOpen}
        onClose={() => setHealthModalOpen(false)}
        title="Evaluate Strategy Health"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setHealthModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="evaluate-health-form"
              loading={evaluateHealthMutation.isPending}
            >
              Evaluate
            </Button>
          </>
        }
      >
        <form
          id="evaluate-health-form"
          onSubmit={handleEvaluateHealth}
          className="space-y-4"
        >
          <Select
            label="Strategy Config"
            required
            value={healthConfigId}
            onChange={(event) => {
              setHealthConfigId(event.target.value);
              const config = configs.find((c) => c.id === event.target.value);
              if (config) setHealthPortfolioId(config.portfolio_id);
            }}
          >
            <option value="" disabled>
              Select a strategy config
            </option>
            {configs.map((config) => (
              <option key={config.id} value={config.id}>
                {strategyName(config.strategy_id)} ·{" "}
                {portfolioName(config.portfolio_id)}
              </option>
            ))}
          </Select>
          <Select
            label="Portfolio"
            required
            value={healthPortfolioId}
            onChange={(event) => setHealthPortfolioId(event.target.value)}
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

          {evaluateHealthMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {evaluateHealthMutation.error.message}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
