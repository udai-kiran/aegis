import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useQueries, useQuery } from "@tanstack/react-query";
import clsx from "clsx";
import { Activity, Briefcase, DollarSign, TrendingUp } from "lucide-react";
import { getPortfolioDashboard, getPortfolios } from "../api/portfolios";
import { getStrategies } from "../api/strategies";
import { useAuthStore } from "../stores/auth";
import { Badge } from "../components/ui/Badge";
import { Card } from "../components/ui/Card";
import { EmptyState } from "../components/ui/EmptyState";
import { Spinner } from "../components/ui/Spinner";
import { StatCard } from "../components/ui/StatCard";
import type { PortfolioDashboard } from "../types";

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

export default function DashboardPage() {
  const tenantId = useAuthStore((state) => state.tenantId);
  const email = useAuthStore((state) => state.email);

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const strategiesQuery = useQuery({
    queryKey: ["strategies", tenantId],
    queryFn: () => getStrategies(tenantId as string),
    enabled: tenantId !== null,
  });

  const portfolios = portfoliosQuery.data ?? [];

  // Per-portfolio dashboards supply daily P&L and positions count, which the
  // portfolio list endpoint does not return.
  const dashboardQueries = useQueries({
    queries: portfolios.map((portfolio) => ({
      queryKey: ["portfolio-dashboard", tenantId, portfolio.id],
      queryFn: () => getPortfolioDashboard(tenantId as string, portfolio.id),
      enabled: tenantId !== null,
    })),
  });

  const dashboardsByPortfolioId = useMemo(() => {
    const map = new Map<string, PortfolioDashboard>();
    dashboardQueries.forEach((result, index) => {
      const portfolio = portfolios[index];
      if (portfolio && result.data) {
        map.set(portfolio.id, result.data);
      }
    });
    return map;
  }, [dashboardQueries, portfolios]);

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant before viewing the dashboard."
        />
      </Card>
    );
  }

  if (portfoliosQuery.isPending) {
    return (
      <div className="flex justify-center py-24 text-brand-600">
        <Spinner size="lg" />
      </div>
    );
  }

  if (portfoliosQuery.isError) {
    return (
      <Card>
        <p className="text-sm text-loss">
          Failed to load portfolios: {portfoliosQuery.error.message}
        </p>
      </Card>
    );
  }

  const totalEquity = portfolios.reduce(
    (sum, portfolio) => sum + portfolio.current_equity,
    0,
  );
  const dailyPnl = dashboardQueries.reduce(
    (sum, result) => sum + (result.data?.daily_pnl ?? 0),
    0,
  );
  const activeStrategies = (strategiesQuery.data ?? []).filter(
    (strategy) => strategy.is_active,
  ).length;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-slate-800">Dashboard</h1>
        <p className="mt-1 text-sm text-slate-400">
          Welcome back{email ? `, ${email}` : ""}
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Total Portfolios"
          value={portfolios.length}
          icon={Briefcase}
        />
        <StatCard
          label="Total Equity"
          value={currency.format(totalEquity)}
          icon={DollarSign}
        />
        <StatCard
          label="Daily P&L"
          value={
            <span className={clsx(dailyPnl >= 0 ? "text-profit" : "text-loss")}>
              {dailyPnl >= 0 ? "+" : ""}
              {currency.format(dailyPnl)}
            </span>
          }
          icon={TrendingUp}
        />
        <StatCard
          label="Active Strategies"
          value={activeStrategies}
          icon={Activity}
        />
      </div>

      {portfolios.length === 0 ? (
        <Card>
          <EmptyState
            title="No portfolios yet"
            description="Create your first portfolio from the Portfolios page to start trading."
            action={
              <Link
                to="/portfolios"
                className="rounded-md bg-brand-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-brand-700"
              >
                Go to Portfolios
              </Link>
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {portfolios.map((portfolio) => {
            const dashboard = dashboardsByPortfolioId.get(portfolio.id);
            const pnl = portfolio.current_equity - portfolio.starting_capital;
            return (
              <Link
                key={portfolio.id}
                to={`/portfolios/${portfolio.id}`}
                className="block rounded-lg transition-shadow focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-500"
              >
                <Card className="h-full transition-colors hover:border-brand-500/50">
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="text-sm font-medium text-slate-800">
                      {portfolio.name}
                    </h3>
                    <Badge variant={tradingModeVariant(portfolio.trading_mode)}>
                      {portfolio.trading_mode}
                    </Badge>
                  </div>
                  <p className="mt-3 text-2xl font-semibold text-slate-800">
                    {currency.format(portfolio.current_equity)}
                  </p>
                  <div className="mt-2 flex items-center justify-between text-sm">
                    <span
                      className={clsx(
                        "font-medium",
                        pnl >= 0 ? "text-profit" : "text-loss",
                      )}
                    >
                      {pnl >= 0 ? "+" : ""}
                      {currency.format(pnl)}
                    </span>
                    <span className="text-slate-400">
                      {dashboard
                        ? `${dashboard.positions_count} positions`
                        : "— positions"}
                    </span>
                  </div>
                </Card>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
