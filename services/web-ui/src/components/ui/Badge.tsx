import { type HTMLAttributes } from "react";
import clsx from "clsx";

type BadgeVariant = "success" | "warning" | "danger" | "info" | "neutral";

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant;
}

const variantClasses: Record<BadgeVariant, string> = {
  success: "bg-profit/10 text-profit",
  warning: "bg-warn/10 text-warn",
  danger: "bg-loss/10 text-loss",
  info: "bg-brand-500/10 text-brand-400",
  neutral: "bg-surface-2 text-slate-400",
};

export function Badge({
  variant = "neutral",
  className,
  ...props
}: BadgeProps) {
  return (
    <span
      className={clsx(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        variantClasses[variant],
        className,
      )}
      {...props}
    />
  );
}
