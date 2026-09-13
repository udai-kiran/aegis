import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import clsx from "clsx";
import { Plus } from "lucide-react";
import { createPortfolio, getPortfolios } from "../api/portfolios";
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

export default function PortfoliosPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const tenantId = useAuthStore((state) => state.tenantId);

  const [modalOpen, setModalOpen] = useState(false);
  const [name, setName] = useState("");
  const [startingCapital, setStartingCapital] = useState("100000");
  const [tradingMode, setTradingMode] = useState("PAPER");

  const portfoliosQuery = useQuery({
    queryKey: ["portfolios", tenantId],
    queryFn: () => getPortfolios(tenantId as string),
    enabled: tenantId !== null,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      createPortfolio(tenantId as string, {
        name: name.trim(),
        starting_capital: Number(startingCapital),
        trading_mode: tradingMode,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["portfolios", tenantId],
      });
      setModalOpen(false);
      setName("");
      setStartingCapital("100000");
      setTradingMode("PAPER");
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
          description="You are signed in as a platform admin. Select or create a tenant before managing portfolios."
        />
      </Card>
    );
  }

  const portfolios = portfoliosQuery.data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50">Portfolios</h1>
          <p className="mt-1 text-sm text-slate-400">
            Manage your trading portfolios
          </p>
        </div>
        <Button onClick={() => setModalOpen(true)}>
          <Plus className="size-4" />
          Create Portfolio
        </Button>
      </div>

      {portfoliosQuery.isPending ? (
        <div className="flex justify-center py-24 text-brand-400">
          <Spinner size="lg" />
        </div>
      ) : portfoliosQuery.isError ? (
        <Card>
          <p className="text-sm text-loss">
            Failed to load portfolios: {portfoliosQuery.error.message}
          </p>
        </Card>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Trading Mode</TableHead>
              <TableHead>Starting Capital</TableHead>
              <TableHead>Current Equity</TableHead>
              <TableHead>Cash</TableHead>
              <TableHead>P&L</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {portfolios.length === 0 ? (
              <TableEmpty
                colSpan={7}
                message="No portfolios yet. Create one to get started."
              />
            ) : (
              portfolios.map((portfolio) => {
                const pnl =
                  portfolio.current_equity - portfolio.starting_capital;
                return (
                  <TableRow
                    key={portfolio.id}
                    onClick={() => navigate(`/portfolios/${portfolio.id}`)}
                    className="cursor-pointer"
                  >
                    <TableCell className="font-medium">
                      {portfolio.name}
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant={tradingModeVariant(portfolio.trading_mode)}
                      >
                        {portfolio.trading_mode}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {currency.format(portfolio.starting_capital)}
                    </TableCell>
                    <TableCell>
                      {currency.format(portfolio.current_equity)}
                    </TableCell>
                    <TableCell>{currency.format(portfolio.cash)}</TableCell>
                    <TableCell
                      className={clsx(
                        "font-medium",
                        pnl >= 0 ? "text-profit" : "text-loss",
                      )}
                    >
                      {pnl >= 0 ? "+" : ""}
                      {currency.format(pnl)}
                    </TableCell>
                    <TableCell className="text-slate-400">
                      {format(new Date(portfolio.created_at), "MMM d, yyyy")}
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      )}

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title="Create Portfolio"
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-portfolio-form"
              loading={createMutation.isPending}
            >
              Create
            </Button>
          </>
        }
      >
        <form
          id="create-portfolio-form"
          onSubmit={handleSubmit}
          className="space-y-4"
        >
          <Input
            label="Name"
            required
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Growth Portfolio"
          />
          <Input
            label="Starting Capital"
            type="number"
            required
            min="0"
            step="0.01"
            value={startingCapital}
            onChange={(event) => setStartingCapital(event.target.value)}
          />
          <Select
            label="Trading Mode"
            value={tradingMode}
            onChange={(event) => setTradingMode(event.target.value)}
          >
            <option value="PAPER">PAPER</option>
            <option value="LIVE">LIVE</option>
          </Select>

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
