import { useId, type ComponentPropsWithRef } from "react";
import { ChevronDown } from "lucide-react";
import clsx from "clsx";

interface SelectProps extends ComponentPropsWithRef<"select"> {
  label?: string;
  error?: string;
}

export function Select({
  label,
  error,
  id,
  className,
  ref,
  children,
  ...props
}: SelectProps) {
  const generatedId = useId();
  const selectId = id ?? generatedId;

  return (
    <div className="w-full">
      {label !== undefined && (
        <label htmlFor={selectId} className="mb-1 block text-sm text-slate-600">
          {label}
        </label>
      )}
      <div className="relative">
        <select
          ref={ref}
          id={selectId}
          className={clsx(
            "w-full appearance-none rounded-md border bg-white py-2 pl-3 pr-8 text-sm text-slate-800",
            "focus:outline-none focus:ring-1",
            error
              ? "border-loss focus:border-loss focus:ring-loss"
              : "border-slate-300 focus:border-brand-500 focus:ring-brand-500",
            className,
          )}
          aria-invalid={error ? true : undefined}
          {...props}
        >
          {children}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 size-4 -translate-y-1/2 text-slate-500" />
      </div>
      {error && <p className="mt-1 text-xs text-loss">{error}</p>}
    </div>
  );
}
