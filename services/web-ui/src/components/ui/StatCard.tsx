import { type ReactNode } from "react";
import { TrendingDown, TrendingUp, type LucideIcon } from "lucide-react";
import clsx from "clsx";
import { Card } from "./Card";

interface StatCardProps {
  label: string;
  value: ReactNode;
  /** Percentage change; positive renders up/profit, negative renders down/loss. */
  change?: number;
  changeLabel?: string;
  icon?: LucideIcon;
  className?: string;
}

export function StatCard({
  label,
  value,
  change,
  changeLabel,
  icon: Icon,
  className,
}: StatCardProps) {
  const hasChange = change !== undefined;
  const isPositive = hasChange && change >= 0;

  return (
    <Card className={className}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-slate-500">{label}</p>
          <p className="mt-1 text-2xl font-semibold text-slate-800">{value}</p>
          {hasChange && (
            <p
              className={clsx(
                "mt-1 flex items-center gap-1 text-xs font-medium",
                isPositive ? "text-profit" : "text-loss",
              )}
            >
              {isPositive ? (
                <TrendingUp className="size-3.5" />
              ) : (
                <TrendingDown className="size-3.5" />
              )}
              {isPositive ? "+" : ""}
              {change.toFixed(2)}%{changeLabel ? ` ${changeLabel}` : ""}
            </p>
          )}
        </div>
        {Icon !== undefined && (
          <div className="rounded-md bg-surface-2 p-2">
            <Icon className="size-5 text-brand-600" />
          </div>
        )}
      </div>
    </Card>
  );
}
