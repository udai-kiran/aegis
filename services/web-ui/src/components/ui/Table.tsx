import {
  type HTMLAttributes,
  type ReactNode,
  type TdHTMLAttributes,
  type ThHTMLAttributes,
} from "react";
import clsx from "clsx";

export function Table({
  className,
  children,
  ...props
}: HTMLAttributes<HTMLTableElement>) {
  return (
    <div className="overflow-x-auto rounded-lg border border-surface-3 bg-surface-1">
      <table className={clsx("w-full text-sm", className)} {...props}>
        {children}
      </table>
    </div>
  );
}

export function TableHeader({
  className,
  ...props
}: HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <thead
      className={clsx("border-b border-surface-3", className)}
      {...props}
    />
  );
}

export function TableBody({
  className,
  ...props
}: HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <tbody
      className={clsx("divide-y divide-surface-3", className)}
      {...props}
    />
  );
}

export function TableRow({
  className,
  ...props
}: HTMLAttributes<HTMLTableRowElement>) {
  return (
    <tr
      className={clsx("transition-colors hover:bg-surface-2/50", className)}
      {...props}
    />
  );
}

export function TableHead({
  className,
  ...props
}: ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th
      className={clsx(
        "px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-400",
        className,
      )}
      {...props}
    />
  );
}

export function TableCell({
  className,
  ...props
}: TdHTMLAttributes<HTMLTableCellElement>) {
  return (
    <td className={clsx("px-4 py-3 text-slate-50", className)} {...props} />
  );
}

interface TableEmptyProps {
  colSpan: number;
  message?: ReactNode;
}

export function TableEmpty({
  colSpan,
  message = "No data available",
}: TableEmptyProps) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-12 text-center text-slate-400">
        {message}
      </td>
    </tr>
  );
}
