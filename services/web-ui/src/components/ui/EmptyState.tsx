import { type ReactNode } from "react";
import { Inbox, type LucideIcon } from "lucide-react";
import clsx from "clsx";

interface EmptyStateProps {
  icon?: LucideIcon;
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({
  icon: Icon = Inbox,
  title,
  description,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={clsx(
        "flex flex-col items-center justify-center px-4 py-12 text-center",
        className,
      )}
    >
      <Icon className="size-10 text-surface-3" />
      <h3 className="mt-3 text-sm font-medium text-slate-50">{title}</h3>
      {description !== undefined && (
        <p className="mt-1 max-w-sm text-sm text-slate-400">{description}</p>
      )}
      {action !== undefined && <div className="mt-4">{action}</div>}
    </div>
  );
}
