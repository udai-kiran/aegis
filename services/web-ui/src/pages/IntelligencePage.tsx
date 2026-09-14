import { Fragment, useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Plus } from "lucide-react";
import {
  allocate,
  computeMarketRegime,
  evaluateCounterfactual,
  getAIDecisions,
  getMarketRegimes,
  getSupervisorActions,
  recommendSupervisorActions,
} from "../api/intelligence";
import { createNewsItem, getNewsItems } from "../api/news";
import { getPortfolios } from "../api/portfolios";
import { useAuthStore } from "../stores/auth";
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
type Tab =
  "ai-decisions" | "regimes" | "supervisor" | "counterfactual" | "news";
type SentimentLabel = "POSITIVE" | "NEGATIVE" | "NEUTRAL";

const tabs: { id: Tab; label: string }[] = [
  { id: "ai-decisions", label: "AI Decisions" },
  { id: "regimes", label: "Market Regimes" },
  { id: "supervisor", label: "Supervisor" },
  { id: "counterfactual", label: "Counterfactual" },
  { id: "news", label: "News" },
];

const modeVariant: Record<string, BadgeVariant> = {
  LIVE: "success",
  SHADOW: "info",
};

const regimeVariant: Record<string, BadgeVariant> = {
  BULL: "success",
  BEAR: "danger",
  SIDEWAYS: "warning",
};

const supervisorStatusVariant: Record<string, BadgeVariant> = {
  APPROVED: "success",
  EXECUTED: "success",
  PENDING: "warning",
  REJECTED: "danger",
};

const sentimentVariant: Record<string, BadgeVariant> = {
  POSITIVE: "success",
  NEGATIVE: "danger",
  NEUTRAL: "neutral",
};

function truncate(text: string | null, max: number): string {
  if (text === null || text === "") return "—";
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

function pct(value: number): string {
  return `${(value * 100).toFixed(1)}%`;
}

function signedPct(value: number): string {
  return `${value >= 0 ? "+" : ""}${(value * 100).toFixed(2)}%`;
}

function formatWeights(weights: Record<string, unknown>): string {
  const entries = Object.entries(weights);
  if (entries.length === 0) return "—";
  return entries
    .map(([key, value]) =>
      typeof value === "number"
        ? `${key}: ${pct(value)}`
        : `${key}: ${String(value)}`,
    )
    .join(", ");
}

function jsonBlock(data: unknown) {
  return (
    <pre className="text-xs text-slate-400 bg-surface-2 rounded p-2 overflow-x-auto max-h-48">
      {JSON.stringify(data, null, 2)}
    </pre>
  );
}

function RegimeBadge({ label }: { label: string }) {
  if (label === "VOLATILE") {
    return (
      <span className="inline-flex items-center rounded-full bg-purple-500/10 px-2 py-0.5 text-xs font-medium text-purple-600">
        {label}
      </span>
    );
  }
  return <Badge variant={regimeVariant[label] ?? "neutral"}>{label}</Badge>;
}

export default function IntelligencePage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [tab, setTab] = useState<Tab>("ai-decisions");

  // Expanded rows
  const [expandedDecisionId, setExpandedDecisionId] = useState<string | null>(
    null,
  );
  const [expandedActionId, setExpandedActionId] = useState<string | null>(null);

  // Run Allocation modal
  const [allocateModalOpen, setAllocateModalOpen] = useState(false);
  const [allocatePortfolioId, setAllocatePortfolioId] = useState("");
  const [allocateMode, setAllocateMode] = useState<"LIVE" | "SHADOW">("SHADOW");

  // Compute Regime modal
  const [regimeModalOpen, setRegimeModalOpen] = useState(false);
  const [regimeSymbol, setRegimeSymbol] = useState("");
  const [regimeExchange, setRegimeExchange] = useState("NSE");
  const [regimeTimeframe, setRegimeTimeframe] = useState("1d");
  const [regimeLookback, setRegimeLookback] = useState("50");

  // Request Recommendation modal
  const [supervisorModalOpen, setSupervisorModalOpen] = useState(false);
  const [supervisorPortfolioId, setSupervisorPortfolioId] = useState("");
  const [supervisorDecisionId, setSupervisorDecisionId] = useState("");

  // Counterfactual form
  const [cfDecisionId, setCfDecisionId] = useState("");
  const [cfStart, setCfStart] = useState("");
  const [cfEnd, setCfEnd] = useState("");

  // Add News modal
  const [newsModalOpen, setNewsModalOpen] = useState(false);
  const [newsHeadline, setNewsHeadline] = useState("");
  const [newsSource, setNewsSource] = useState("");
  const [newsUrl, setNewsUrl] = useState("");
  const [newsSymbols, setNewsSymbols] = useState("");
  const [newsSentimentScore, setNewsSentimentScore] = useState("0");
  const [newsSentimentLabel, setNewsSentimentLabel] =
    useState<SentimentLabel>("NEUTRAL");
  const [newsPublishedAt, setNewsPublishedAt] = useState("");

  const decisionsQuery = useQuery({
    queryKey: ["ai-decisions", tenantId],
    queryFn: () => getAIDecisions(tenantId as string),
    enabled: tenantId !== null,
  });

  const regimesQuery = useQuery({
    queryKey: ["market-regimes"],
    queryFn: () => getMarketRegimes(),
  });

  const supervisorQuery = useQuery({
    queryKey: ["supervisor-actions", tenantId],
    queryFn: () => getSupervisorActions(tenantId as string),
    enabled: tenantId !== null,
  });

  const newsQuery = useQuery({
    queryKey: ["news", tenantId],
    queryFn: () => getNewsItems(tenantId as string),
    enabled: tenantId !== null,
  });

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const allocateMutation = useMutation({
    mutationFn: () =>
      allocate(tenantId as string, {
        portfolio_id: allocatePortfolioId,
        mode: allocateMode,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["ai-decisions", tenantId],
      });
      setAllocateModalOpen(false);
      setAllocatePortfolioId("");
      setAllocateMode("SHADOW");
    },
  });

  const regimeMutation = useMutation({
    mutationFn: () =>
      computeMarketRegime({
        symbol: regimeSymbol.trim(),
        exchange: regimeExchange.trim() || "NSE",
        timeframe: regimeTimeframe.trim() || "1d",
        lookback_bars: Number(regimeLookback) || 50,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["market-regimes"] });
      setRegimeModalOpen(false);
      setRegimeSymbol("");
      setRegimeExchange("NSE");
      setRegimeTimeframe("1d");
      setRegimeLookback("50");
    },
  });

  const supervisorMutation = useMutation({
    mutationFn: () =>
      recommendSupervisorActions(tenantId as string, {
        portfolio_id: supervisorPortfolioId,
        decision_id: supervisorDecisionId.trim() || null,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["supervisor-actions", tenantId],
      });
      setSupervisorModalOpen(false);
      setSupervisorPortfolioId("");
      setSupervisorDecisionId("");
    },
  });

  const counterfactualMutation = useMutation({
    mutationFn: () =>
      evaluateCounterfactual(tenantId as string, {
        ai_decision_id: cfDecisionId.trim(),
        evaluation_start: new Date(cfStart).toISOString(),
        evaluation_end: new Date(cfEnd).toISOString(),
      }),
  });

  const newsMutation = useMutation({
    mutationFn: () =>
      createNewsItem(tenantId as string, {
        headline: newsHeadline.trim(),
        source: newsSource.trim() || null,
        url: newsUrl.trim() || null,
        symbols: newsSymbols
          .split(",")
          .map((symbol) => symbol.trim())
          .filter((symbol) => symbol !== ""),
        sentiment_score: Number(newsSentimentScore),
        sentiment_label: newsSentimentLabel,
        published_at: new Date(newsPublishedAt).toISOString(),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["news", tenantId] });
      setNewsModalOpen(false);
      setNewsHeadline("");
      setNewsSource("");
      setNewsUrl("");
      setNewsSymbols("");
      setNewsSentimentScore("0");
      setNewsSentimentLabel("NEUTRAL");
      setNewsPublishedAt("");
    },
  });

  function handleAllocate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    allocateMutation.mutate();
  }

  function handleComputeRegime(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    regimeMutation.mutate();
  }

  function handleRequestRecommendation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    supervisorMutation.mutate();
  }

  function handleEvaluateCounterfactual(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    counterfactualMutation.mutate();
  }

  function handleCreateNews(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    newsMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant before viewing intelligence."
        />
      </Card>
    );
  }

  const decisions = decisionsQuery.data ?? [];
  const regimes = regimesQuery.data ?? [];
  const supervisorActions = supervisorQuery.data ?? [];
  const newsItems = newsQuery.data ?? [];
  const portfolios = portfoliosQuery.data ?? [];

  const portfolioName = (id: string): string =>
    portfolios.find((p) => p.id === id)?.name ?? `${id.slice(0, 8)}…`;

  const isPending =
    (tab === "ai-decisions" && decisionsQuery.isPending) ||
    (tab === "regimes" && regimesQuery.isPending) ||
    (tab === "supervisor" && supervisorQuery.isPending) ||
    (tab === "news" && newsQuery.isPending);
  const activeError =
    tab === "ai-decisions"
      ? decisionsQuery.error
      : tab === "regimes"
        ? regimesQuery.error
        : tab === "supervisor"
          ? supervisorQuery.error
          : tab === "news"
            ? newsQuery.error
            : null;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-800">Intelligence</h1>
          <p className="mt-1 text-sm text-slate-400">
            AI decisions, market regimes, supervisor actions, and news
          </p>
        </div>
        {tab === "ai-decisions" && (
          <Button onClick={() => setAllocateModalOpen(true)}>
            <Plus className="size-4" />
            Run Allocation
          </Button>
        )}
        {tab === "regimes" && (
          <Button onClick={() => setRegimeModalOpen(true)}>
            <Plus className="size-4" />
            Compute Regime
          </Button>
        )}
        {tab === "supervisor" && (
          <Button onClick={() => setSupervisorModalOpen(true)}>
            <Plus className="size-4" />
            Request Recommendation
          </Button>
        )}
        {tab === "news" && (
          <Button onClick={() => setNewsModalOpen(true)}>
            <Plus className="size-4" />
            Add News
          </Button>
        )}
      </div>

      <div className="flex gap-1">
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setTab(item.id)}
            className={clsx(
              "rounded-md px-4 py-2 text-sm font-medium transition-colors",
              tab === item.id
                ? "bg-brand-50 text-brand-700"
                : "text-slate-500 hover:bg-slate-100 hover:text-slate-900",
            )}
          >
            {item.label}
          </button>
        ))}
      </div>

      {tab === "counterfactual" ? (
        <>
          <Card header="Evaluate Counterfactual">
            <form
              onSubmit={handleEvaluateCounterfactual}
              className="grid gap-4 sm:grid-cols-3"
            >
              <Input
                label="AI Decision ID"
                required
                value={cfDecisionId}
                onChange={(event) => setCfDecisionId(event.target.value)}
                placeholder="Decision UUID"
              />
              <Input
                label="Evaluation Start"
                type="datetime-local"
                required
                value={cfStart}
                onChange={(event) => setCfStart(event.target.value)}
              />
              <Input
                label="Evaluation End"
                type="datetime-local"
                required
                value={cfEnd}
                onChange={(event) => setCfEnd(event.target.value)}
              />
              <div className="sm:col-span-3">
                <Button
                  type="submit"
                  loading={counterfactualMutation.isPending}
                >
                  Evaluate
                </Button>
              </div>
              {counterfactualMutation.isError && (
                <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss sm:col-span-3">
                  {counterfactualMutation.error.message}
                </p>
              )}
            </form>
          </Card>

          {counterfactualMutation.data && (
            <Card header="Results">
              <div className="grid gap-4 sm:grid-cols-3">
                <div>
                  <p className="text-xs uppercase tracking-wider text-slate-400">
                    Actual Weighted Return
                  </p>
                  <p
                    className={clsx(
                      "mt-1 text-lg font-semibold",
                      counterfactualMutation.data.actual_weighted_return >= 0
                        ? "text-profit"
                        : "text-loss",
                    )}
                  >
                    {signedPct(
                      counterfactualMutation.data.actual_weighted_return,
                    )}
                  </p>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wider text-slate-400">
                    Best Alternative Return
                  </p>
                  <p
                    className={clsx(
                      "mt-1 text-lg font-semibold",
                      counterfactualMutation.data.best_alternative_return >= 0
                        ? "text-profit"
                        : "text-loss",
                    )}
                  >
                    {signedPct(
                      counterfactualMutation.data.best_alternative_return,
                    )}
                  </p>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-wider text-slate-400">
                    Regret
                  </p>
                  <p
                    className={clsx(
                      "mt-1 text-lg font-semibold",
                      counterfactualMutation.data.regret > 0
                        ? "text-loss"
                        : "text-profit",
                    )}
                  >
                    {signedPct(counterfactualMutation.data.regret)}
                  </p>
                </div>
              </div>

              <div className="mt-4">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Strategy Name</TableHead>
                      <TableHead>Was Chosen</TableHead>
                      <TableHead>Weight</TableHead>
                      <TableHead>Hypothetical Return</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {counterfactualMutation.data.comparisons.length === 0 ? (
                      <TableEmpty
                        colSpan={4}
                        message="No comparisons available"
                      />
                    ) : (
                      counterfactualMutation.data.comparisons.map((item) => (
                        <TableRow key={item.strategy_config_id}>
                          <TableCell className="font-medium">
                            {item.strategy_name}
                          </TableCell>
                          <TableCell>
                            <Badge
                              variant={item.was_chosen ? "success" : "neutral"}
                            >
                              {item.was_chosen ? "Yes" : "No"}
                            </Badge>
                          </TableCell>
                          <TableCell>{pct(item.weight)}</TableCell>
                          <TableCell
                            className={clsx(
                              item.hypothetical_return >= 0
                                ? "text-profit"
                                : "text-loss",
                            )}
                          >
                            {signedPct(item.hypothetical_return)}
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </div>
            </Card>
          )}
        </>
      ) : isPending ? (
        <div className="flex justify-center py-24 text-brand-600">
          <Spinner size="lg" />
        </div>
      ) : activeError ? (
        <Card>
          <p className="text-sm text-loss">
            Failed to load data: {activeError.message}
          </p>
        </Card>
      ) : tab === "ai-decisions" ? (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Portfolio</TableHead>
              <TableHead>Strategy Weights</TableHead>
              <TableHead>Cash Weight</TableHead>
              <TableHead>Confidence</TableHead>
              <TableHead>Mode</TableHead>
              <TableHead>Explanation</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {decisions.length === 0 ? (
              <TableEmpty
                colSpan={7}
                message="No AI decisions yet. Run an allocation to get started."
              />
            ) : (
              decisions.map((decision) => (
                <Fragment key={decision.id}>
                  <TableRow
                    onClick={() =>
                      setExpandedDecisionId(
                        expandedDecisionId === decision.id ? null : decision.id,
                      )
                    }
                    className="cursor-pointer"
                  >
                    <TableCell className="font-medium">
                      {portfolioName(decision.portfolio_id)}
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-slate-400">
                      {formatWeights(decision.strategy_weights)}
                    </TableCell>
                    <TableCell>{pct(decision.cash_weight)}</TableCell>
                    <TableCell>{pct(decision.confidence)}</TableCell>
                    <TableCell>
                      <Badge variant={modeVariant[decision.mode] ?? "neutral"}>
                        {decision.mode}
                      </Badge>
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-slate-400">
                      {truncate(decision.explanation, 80)}
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(
                        new Date(decision.created_at),
                        "MMM d, yyyy HH:mm",
                      )}
                    </TableCell>
                  </TableRow>
                  {expandedDecisionId === decision.id && (
                    <TableRow key={`${decision.id}-expanded`}>
                      <TableCell colSpan={7} className="bg-surface-2/30">
                        <div className="space-y-3">
                          <div>
                            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                              Explanation
                            </p>
                            <p className="text-sm text-slate-800">
                              {decision.explanation ?? "—"}
                            </p>
                          </div>
                          <div>
                            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                              Context Snapshot
                            </p>
                            {jsonBlock(decision.context_snapshot)}
                          </div>
                          <div>
                            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                              Reward Params
                            </p>
                            {jsonBlock(decision.reward_params)}
                          </div>
                        </div>
                      </TableCell>
                    </TableRow>
                  )}
                </Fragment>
              ))
            )}
          </TableBody>
        </Table>
      ) : tab === "regimes" ? (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Symbol</TableHead>
              <TableHead>Exchange</TableHead>
              <TableHead>Regime Label</TableHead>
              <TableHead>Confidence</TableHead>
              <TableHead>Computed At</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {regimes.length === 0 ? (
              <TableEmpty
                colSpan={5}
                message="No market regimes yet. Compute one to get started."
              />
            ) : (
              regimes.map((regime) => (
                <TableRow key={regime.id}>
                  <TableCell className="font-medium">{regime.symbol}</TableCell>
                  <TableCell>{regime.exchange}</TableCell>
                  <TableCell>
                    <RegimeBadge label={regime.regime_label} />
                  </TableCell>
                  <TableCell>{pct(regime.confidence)}</TableCell>
                  <TableCell className="text-slate-400">
                    {format(new Date(regime.computed_at), "MMM d, yyyy HH:mm")}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      ) : tab === "supervisor" ? (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Action Type</TableHead>
              <TableHead>Recommendation</TableHead>
              <TableHead>Reasoning</TableHead>
              <TableHead>Confidence</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {supervisorActions.length === 0 ? (
              <TableEmpty
                colSpan={6}
                message="No supervisor actions yet. Request a recommendation to get started."
              />
            ) : (
              supervisorActions.map((action) => (
                <Fragment key={action.id}>
                  <TableRow
                    onClick={() =>
                      setExpandedActionId(
                        expandedActionId === action.id ? null : action.id,
                      )
                    }
                    className="cursor-pointer"
                  >
                    <TableCell className="font-medium">
                      {action.action_type}
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-slate-400">
                      <code>
                        {truncate(JSON.stringify(action.recommendation), 80)}
                      </code>
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-slate-400">
                      {truncate(action.reasoning, 100)}
                    </TableCell>
                    <TableCell>{pct(action.confidence)}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          supervisorStatusVariant[action.status] ?? "neutral"
                        }
                      >
                        {action.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(new Date(action.created_at), "MMM d, yyyy HH:mm")}
                    </TableCell>
                  </TableRow>
                  {expandedActionId === action.id && (
                    <TableRow key={`${action.id}-expanded`}>
                      <TableCell colSpan={6} className="bg-surface-2/30">
                        <div className="space-y-3">
                          <div>
                            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                              Reasoning
                            </p>
                            <p className="text-sm text-slate-800">
                              {action.reasoning ?? "—"}
                            </p>
                          </div>
                          <div>
                            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-slate-400">
                              Recommendation
                            </p>
                            {jsonBlock(action.recommendation)}
                          </div>
                        </div>
                      </TableCell>
                    </TableRow>
                  )}
                </Fragment>
              ))
            )}
          </TableBody>
        </Table>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Headline</TableHead>
              <TableHead>Source</TableHead>
              <TableHead>Sentiment</TableHead>
              <TableHead>Score</TableHead>
              <TableHead>Symbols</TableHead>
              <TableHead>Published At</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {newsItems.length === 0 ? (
              <TableEmpty
                colSpan={6}
                message="No news items yet. Add one to get started."
              />
            ) : (
              newsItems.map((item) => (
                <TableRow key={item.id}>
                  <TableCell className="max-w-md truncate font-medium">
                    {item.headline}
                  </TableCell>
                  <TableCell className="text-slate-400">
                    {item.source ?? "—"}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={
                        sentimentVariant[item.sentiment_label] ?? "neutral"
                      }
                    >
                      {item.sentiment_label}
                    </Badge>
                  </TableCell>
                  <TableCell
                    className={clsx(
                      item.sentiment_score > 0
                        ? "text-profit"
                        : item.sentiment_score < 0
                          ? "text-loss"
                          : "text-slate-400",
                    )}
                  >
                    {item.sentiment_score.toFixed(2)}
                  </TableCell>
                  <TableCell className="text-slate-400">
                    {item.symbols !== null && item.symbols.length > 0
                      ? item.symbols.join(", ")
                      : "—"}
                  </TableCell>
                  <TableCell className="text-slate-400">
                    {format(new Date(item.published_at), "MMM d, yyyy HH:mm")}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      )}

      <Modal
        open={allocateModalOpen}
        onClose={() => setAllocateModalOpen(false)}
        title="Run Allocation"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setAllocateModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="run-allocation-form"
              loading={allocateMutation.isPending}
            >
              Run
            </Button>
          </>
        }
      >
        <form
          id="run-allocation-form"
          onSubmit={handleAllocate}
          className="space-y-4"
        >
          <Input
            label="Portfolio ID"
            required
            value={allocatePortfolioId}
            onChange={(event) => setAllocatePortfolioId(event.target.value)}
            placeholder="Portfolio UUID"
          />
          <Select
            label="Mode"
            value={allocateMode}
            onChange={(event) =>
              setAllocateMode(event.target.value as "LIVE" | "SHADOW")
            }
          >
            <option value="LIVE">LIVE</option>
            <option value="SHADOW">SHADOW</option>
          </Select>

          {allocateMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {allocateMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={regimeModalOpen}
        onClose={() => setRegimeModalOpen(false)}
        title="Compute Regime"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setRegimeModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="compute-regime-form"
              loading={regimeMutation.isPending}
            >
              Compute
            </Button>
          </>
        }
      >
        <form
          id="compute-regime-form"
          onSubmit={handleComputeRegime}
          className="space-y-4"
        >
          <Input
            label="Symbol"
            required
            value={regimeSymbol}
            onChange={(event) => setRegimeSymbol(event.target.value)}
            placeholder="RELIANCE"
          />
          <Input
            label="Exchange"
            value={regimeExchange}
            onChange={(event) => setRegimeExchange(event.target.value)}
            placeholder="NSE"
          />
          <Input
            label="Timeframe"
            value={regimeTimeframe}
            onChange={(event) => setRegimeTimeframe(event.target.value)}
            placeholder="1d"
          />
          <Input
            label="Lookback Bars"
            type="number"
            min={1}
            value={regimeLookback}
            onChange={(event) => setRegimeLookback(event.target.value)}
          />

          {regimeMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {regimeMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={supervisorModalOpen}
        onClose={() => setSupervisorModalOpen(false)}
        title="Request Recommendation"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setSupervisorModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="request-recommendation-form"
              loading={supervisorMutation.isPending}
            >
              Request
            </Button>
          </>
        }
      >
        <form
          id="request-recommendation-form"
          onSubmit={handleRequestRecommendation}
          className="space-y-4"
        >
          <Input
            label="Portfolio ID"
            required
            value={supervisorPortfolioId}
            onChange={(event) => setSupervisorPortfolioId(event.target.value)}
            placeholder="Portfolio UUID"
          />
          <Input
            label="Decision ID (optional)"
            value={supervisorDecisionId}
            onChange={(event) => setSupervisorDecisionId(event.target.value)}
            placeholder="AI decision UUID"
          />

          {supervisorMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {supervisorMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={newsModalOpen}
        onClose={() => setNewsModalOpen(false)}
        title="Add News"
        footer={
          <>
            <Button variant="secondary" onClick={() => setNewsModalOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="add-news-form"
              loading={newsMutation.isPending}
            >
              Add
            </Button>
          </>
        }
      >
        <form
          id="add-news-form"
          onSubmit={handleCreateNews}
          className="space-y-4"
        >
          <Input
            label="Headline"
            required
            value={newsHeadline}
            onChange={(event) => setNewsHeadline(event.target.value)}
            placeholder="Market rallies on rate cut hopes"
          />
          <Input
            label="Source"
            value={newsSource}
            onChange={(event) => setNewsSource(event.target.value)}
            placeholder="Reuters"
          />
          <Input
            label="URL"
            type="url"
            value={newsUrl}
            onChange={(event) => setNewsUrl(event.target.value)}
            placeholder="https://…"
          />
          <Input
            label="Symbols (comma-separated)"
            value={newsSymbols}
            onChange={(event) => setNewsSymbols(event.target.value)}
            placeholder="RELIANCE, TCS"
          />
          <Input
            label="Sentiment Score (-1 to 1)"
            type="number"
            required
            min={-1}
            max={1}
            step="0.01"
            value={newsSentimentScore}
            onChange={(event) => setNewsSentimentScore(event.target.value)}
          />
          <Select
            label="Sentiment Label"
            value={newsSentimentLabel}
            onChange={(event) =>
              setNewsSentimentLabel(event.target.value as SentimentLabel)
            }
          >
            <option value="POSITIVE">POSITIVE</option>
            <option value="NEGATIVE">NEGATIVE</option>
            <option value="NEUTRAL">NEUTRAL</option>
          </Select>
          <Input
            label="Published At"
            type="datetime-local"
            required
            value={newsPublishedAt}
            onChange={(event) => setNewsPublishedAt(event.target.value)}
          />

          {newsMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {newsMutation.error.message}
            </p>
          )}
        </form>
      </Modal>
    </div>
  );
}
