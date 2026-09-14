import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { OctagonAlert, Plus } from "lucide-react";
import {
  applyKillSwitch,
  createRiskPolicy,
  emergencyHalt,
  getKillSwitchStatus,
  getRiskPolicies,
  updateRiskPolicy,
} from "../api/risk";
import { getPortfolios } from "../api/portfolios";
import { getBrokerAccounts } from "../api/broker-accounts";
import { useAuthStore } from "../stores/auth";
import type {
  RiskPolicyCreate,
  RiskPolicyResponse,
  RiskPolicyUpdate,
} from "../types";
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

type KillSwitchScope = "TENANT" | "PORTFOLIO" | "BROKER_ACCOUNT";

function parseOptionalNumber(value: string): number | null {
  if (value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function pctValue(value: number | null): string {
  return value === null ? "—" : `${value}%`;
}

function moneyValue(value: number | null): string {
  return value === null ? "—" : value.toLocaleString();
}

function leverageValue(value: number | null): string {
  return value === null ? "—" : `${value}x`;
}

/** Badge has no purple variant; render the PORTFOLIO badge inline instead. */
function PolicyTypeBadge({ policyType }: { policyType: string }) {
  if (policyType === "PORTFOLIO") {
    return (
      <span className="inline-flex items-center rounded-full bg-purple-500/10 px-2 py-0.5 text-xs font-medium text-purple-600">
        PORTFOLIO
      </span>
    );
  }
  return (
    <Badge variant={policyType === "TENANT" ? "info" : "neutral"}>
      {policyType}
    </Badge>
  );
}

export default function RiskPage() {
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [policyModalOpen, setPolicyModalOpen] = useState(false);
  const [name, setName] = useState("");
  const [policyType, setPolicyType] = useState("TENANT");
  const [portfolioId, setPortfolioId] = useState("");
  const [maxDailyLossPct, setMaxDailyLossPct] = useState("");
  const [maxDrawdownPct, setMaxDrawdownPct] = useState("");
  const [maxPositionPct, setMaxPositionPct] = useState("");
  const [maxOrderValue, setMaxOrderValue] = useState("");
  const [maxLeverage, setMaxLeverage] = useState("");

  const [scope, setScope] = useState<KillSwitchScope>("TENANT");
  const [targetId, setTargetId] = useState("");
  const [reason, setReason] = useState("");
  const [emergencyModalOpen, setEmergencyModalOpen] = useState(false);

  const policiesQuery = useQuery({
    queryKey: ["risk-policies", tenantId],
    queryFn: () => getRiskPolicies(tenantId as string),
    enabled: tenantId !== null,
  });

  const killSwitchQuery = useQuery({
    queryKey: ["kill-switch", tenantId],
    queryFn: () => getKillSwitchStatus(tenantId as string),
    enabled: tenantId !== null,
  });

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const brokerAccountsQuery = useQuery({
    queryKey: ["broker-accounts", tenantId],
    queryFn: () => getBrokerAccounts(tenantId as string),
    enabled: tenantId !== null,
  });

  const createMutation = useMutation({
    mutationFn: () => {
      const payload: RiskPolicyCreate = {
        name: name.trim(),
        policy_type: policyType,
        portfolio_id: portfolioId === "" ? null : portfolioId,
        max_daily_loss_pct: parseOptionalNumber(maxDailyLossPct),
        max_drawdown_pct: parseOptionalNumber(maxDrawdownPct),
        max_position_pct: parseOptionalNumber(maxPositionPct),
        max_order_value: parseOptionalNumber(maxOrderValue),
        max_leverage: parseOptionalNumber(maxLeverage),
      };
      return createRiskPolicy(tenantId as string, payload);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["risk-policies", tenantId],
      });
      setPolicyModalOpen(false);
      setName("");
      setPolicyType("TENANT");
      setPortfolioId("");
      setMaxDailyLossPct("");
      setMaxDrawdownPct("");
      setMaxPositionPct("");
      setMaxOrderValue("");
      setMaxLeverage("");
    },
  });

  const toggleActiveMutation = useMutation({
    mutationFn: (policy: RiskPolicyResponse) =>
      updateRiskPolicy(tenantId as string, policy.id, {
        is_active: !policy.is_active,
      } as RiskPolicyUpdate),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["risk-policies", tenantId],
      });
    },
  });

  const killSwitchMutation = useMutation({
    mutationFn: (action: "HALT" | "RESUME") =>
      applyKillSwitch(tenantId as string, {
        scope,
        action,
        ...(scope !== "TENANT" && targetId ? { target_id: targetId } : {}),
        ...(reason.trim() ? { reason: reason.trim() } : {}),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["kill-switch", tenantId],
      });
      setReason("");
    },
  });

  const emergencyHaltMutation = useMutation({
    mutationFn: () => emergencyHalt(tenantId as string),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["kill-switch", tenantId],
      });
      setEmergencyModalOpen(false);
    },
  });

  function handleCreateSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    createMutation.mutate();
  }

  if (tenantId === null) {
    return (
      <Card>
        <EmptyState
          title="No tenant selected"
          description="You are signed in as a platform admin. Select or create a tenant in Settings before managing risk."
        />
      </Card>
    );
  }

  const policies = policiesQuery.data ?? [];
  const portfolios = portfoliosQuery.data ?? [];
  const brokerAccounts = brokerAccountsQuery.data ?? [];
  const killSwitchStatus = killSwitchQuery.data;
  const tenantHalted = killSwitchStatus?.tenant_halted ?? false;

  const portfolioName = (id: string): string =>
    portfolios.find((p) => p.id === id)?.name ?? `${id.slice(0, 8)}…`;

  const brokerAccountName = (id: string): string =>
    brokerAccounts.find((a) => a.id === id)?.display_name ??
    `${id.slice(0, 8)}…`;

  const targetOptions =
    scope === "PORTFOLIO"
      ? portfolios.map((p) => ({ id: p.id, label: p.name }))
      : brokerAccounts.map((a) => ({ id: a.id, label: a.display_name }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-800">Risk</h1>
          <p className="mt-1 text-sm text-slate-400">
            Manage risk policies and the trading kill switch
          </p>
        </div>
        <Button onClick={() => setPolicyModalOpen(true)}>
          <Plus className="size-4" />
          Create Policy
        </Button>
      </div>

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-slate-800">Risk Policies</h2>
        {policiesQuery.isPending ? (
          <div className="flex justify-center py-24 text-brand-600">
            <Spinner size="lg" />
          </div>
        ) : policiesQuery.isError ? (
          <Card>
            <p className="text-sm text-loss">
              Failed to load risk policies: {policiesQuery.error.message}
            </p>
          </Card>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Policy Type</TableHead>
                <TableHead>Portfolio</TableHead>
                <TableHead>Max Daily Loss %</TableHead>
                <TableHead>Max Drawdown %</TableHead>
                <TableHead>Max Position %</TableHead>
                <TableHead>Max Order Value</TableHead>
                <TableHead>Max Leverage</TableHead>
                <TableHead>Active</TableHead>
                <TableHead>Created</TableHead>
                <TableHead className="w-24" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {policies.length === 0 ? (
                <TableEmpty
                  colSpan={11}
                  message="No risk policies yet. Create one to get started."
                />
              ) : (
                policies.map((policy) => (
                  <TableRow key={policy.id}>
                    <TableCell className="font-medium">{policy.name}</TableCell>
                    <TableCell>
                      <PolicyTypeBadge policyType={policy.policy_type} />
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {policy.portfolio_id
                        ? portfolioName(policy.portfolio_id)
                        : "—"}
                    </TableCell>
                    <TableCell>{pctValue(policy.max_daily_loss_pct)}</TableCell>
                    <TableCell>{pctValue(policy.max_drawdown_pct)}</TableCell>
                    <TableCell>{pctValue(policy.max_position_pct)}</TableCell>
                    <TableCell>{moneyValue(policy.max_order_value)}</TableCell>
                    <TableCell>{leverageValue(policy.max_leverage)}</TableCell>
                    <TableCell>
                      <Badge variant={policy.is_active ? "success" : "neutral"}>
                        {policy.is_active ? "ACTIVE" : "INACTIVE"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(new Date(policy.created_at), "MMM d, yyyy HH:mm")}
                    </TableCell>
                    <TableCell>
                      <Button
                        size="sm"
                        variant="ghost"
                        loading={
                          toggleActiveMutation.isPending &&
                          toggleActiveMutation.variables?.id === policy.id
                        }
                        onClick={() => toggleActiveMutation.mutate(policy)}
                      >
                        {policy.is_active ? "Deactivate" : "Activate"}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        )}
        {toggleActiveMutation.isError && (
          <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
            {toggleActiveMutation.error.message}
          </p>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium text-slate-800">Kill Switch</h2>
        <Card
          header={
            <div className="flex items-center justify-between">
              <span>Trading Status</span>
              {killSwitchQuery.isPending ? (
                <Spinner size="sm" className="text-brand-600" />
              ) : (
                <span
                  className={clsx(
                    "inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-semibold",
                    tenantHalted
                      ? "bg-loss/10 text-loss"
                      : "bg-profit/10 text-profit",
                  )}
                >
                  <span
                    className={clsx(
                      "size-2 rounded-full",
                      tenantHalted ? "bg-loss" : "bg-profit",
                    )}
                  />
                  {tenantHalted ? "HALTED" : "ACTIVE"}
                </span>
              )}
            </div>
          }
        >
          {killSwitchQuery.isError ? (
            <p className="text-sm text-loss">
              Failed to load kill switch status: {killSwitchQuery.error.message}
            </p>
          ) : (
            <div className="space-y-4">
              {killSwitchStatus &&
                (killSwitchStatus.portfolios_halted.length > 0 ||
                  killSwitchStatus.broker_accounts_halted.length > 0) && (
                  <div>
                    <h3 className="mb-2 text-sm font-medium text-slate-800">
                      Halted entities
                    </h3>
                    <ul className="space-y-1">
                      {killSwitchStatus.portfolios_halted.map((id) => (
                        <li
                          key={id}
                          className="flex items-center gap-2 text-sm text-slate-400"
                        >
                          <Badge variant="danger">PORTFOLIO</Badge>
                          {portfolioName(id)}
                        </li>
                      ))}
                      {killSwitchStatus.broker_accounts_halted.map((id) => (
                        <li
                          key={id}
                          className="flex items-center gap-2 text-sm text-slate-400"
                        >
                          <Badge variant="danger">BROKER ACCOUNT</Badge>
                          {brokerAccountName(id)}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <Select
                  label="Scope"
                  value={scope}
                  onChange={(event) => {
                    setScope(event.target.value as KillSwitchScope);
                    setTargetId("");
                  }}
                >
                  <option value="TENANT">TENANT</option>
                  <option value="PORTFOLIO">PORTFOLIO</option>
                  <option value="BROKER_ACCOUNT">BROKER ACCOUNT</option>
                </Select>
                {scope !== "TENANT" && (
                  <Select
                    label={
                      scope === "PORTFOLIO" ? "Portfolio" : "Broker Account"
                    }
                    value={targetId}
                    onChange={(event) => setTargetId(event.target.value)}
                  >
                    <option value="">Select a target</option>
                    {targetOptions.map((option) => (
                      <option key={option.id} value={option.id}>
                        {option.label}
                      </option>
                    ))}
                  </Select>
                )}
                <Input
                  label="Reason"
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="Optional reason"
                />
              </div>

              {killSwitchMutation.isError && (
                <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
                  {killSwitchMutation.error.message}
                </p>
              )}
              {emergencyHaltMutation.isError && (
                <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
                  {emergencyHaltMutation.error.message}
                </p>
              )}

              <div className="flex flex-wrap items-center gap-3">
                <Button
                  variant="danger"
                  loading={killSwitchMutation.isPending}
                  disabled={scope !== "TENANT" && targetId === ""}
                  onClick={() => killSwitchMutation.mutate("HALT")}
                >
                  Halt Trading
                </Button>
                <Button
                  variant="secondary"
                  loading={killSwitchMutation.isPending}
                  disabled={scope !== "TENANT" && targetId === ""}
                  onClick={() => killSwitchMutation.mutate("RESUME")}
                >
                  Resume Trading
                </Button>
                <div className="flex-1" />
                <Button
                  variant="danger"
                  size="lg"
                  className="font-bold uppercase tracking-wide"
                  onClick={() => setEmergencyModalOpen(true)}
                >
                  <OctagonAlert className="size-5" />
                  Emergency Halt
                </Button>
              </div>
            </div>
          )}
        </Card>
      </section>

      <Modal
        open={policyModalOpen}
        onClose={() => setPolicyModalOpen(false)}
        title="Create Risk Policy"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setPolicyModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-policy-form"
              loading={createMutation.isPending}
            >
              Create
            </Button>
          </>
        }
      >
        <form
          id="create-policy-form"
          onSubmit={handleCreateSubmit}
          className="space-y-4"
        >
          <Input
            label="Name"
            required
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Tenant-wide limits"
          />
          <Select
            label="Policy Type"
            value={policyType}
            onChange={(event) => setPolicyType(event.target.value)}
          >
            <option value="TENANT">TENANT</option>
            <option value="PORTFOLIO">PORTFOLIO</option>
          </Select>
          {policyType === "PORTFOLIO" && (
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
          )}
          <div className="grid grid-cols-2 gap-4">
            <Input
              label="Max Daily Loss %"
              type="number"
              step="0.01"
              value={maxDailyLossPct}
              onChange={(event) => setMaxDailyLossPct(event.target.value)}
              placeholder="5"
            />
            <Input
              label="Max Drawdown %"
              type="number"
              step="0.01"
              value={maxDrawdownPct}
              onChange={(event) => setMaxDrawdownPct(event.target.value)}
              placeholder="15"
            />
            <Input
              label="Max Position %"
              type="number"
              step="0.01"
              value={maxPositionPct}
              onChange={(event) => setMaxPositionPct(event.target.value)}
              placeholder="10"
            />
            <Input
              label="Max Order Value"
              type="number"
              step="0.01"
              value={maxOrderValue}
              onChange={(event) => setMaxOrderValue(event.target.value)}
              placeholder="100000"
            />
            <Input
              label="Max Leverage"
              type="number"
              step="0.1"
              value={maxLeverage}
              onChange={(event) => setMaxLeverage(event.target.value)}
              placeholder="1"
            />
          </div>

          {createMutation.isError && (
            <p className="rounded-md border border-loss/30 bg-loss/10 px-3 py-2 text-sm text-loss">
              {createMutation.error.message}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={emergencyModalOpen}
        onClose={() => setEmergencyModalOpen(false)}
        title="Confirm Emergency Halt"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setEmergencyModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={emergencyHaltMutation.isPending}
              onClick={() => emergencyHaltMutation.mutate()}
            >
              <OctagonAlert className="size-4" />
              Halt All Trading
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-400">
          This will immediately halt{" "}
          <span className="font-medium text-loss">all trading</span> for this
          tenant, including every portfolio and broker account. This action is
          recorded in the audit log. Are you sure?
        </p>
      </Modal>
    </div>
  );
}
