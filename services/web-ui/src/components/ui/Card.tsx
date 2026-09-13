import { type HTMLAttributes, type ReactNode } from "react";
import clsx from "clsx";

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  header?: ReactNode;
  footer?: ReactNode;
  children: ReactNode;
}

export function Card({
  header,
  footer,
  className,
  children,
  ...props
}: CardProps) {
  return (
    <div
      className={clsx(
        "rounded-lg border border-surface-3 bg-surface-1",
        className,
      )}
      {...props}
    >
      {header !== undefined && (
        <div className="border-b border-surface-3 px-4 py-3 text-sm font-medium text-slate-50">
          {header}
        </div>
      )}
      <div className="p-4">{children}</div>
      {footer !== undefined && (
        <div className="border-t border-surface-3 px-4 py-3 text-sm text-slate-400">
          {footer}
        </div>
      )}
    </div>
  );
}
