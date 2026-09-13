import { useId, type ComponentPropsWithRef } from "react";
import clsx from "clsx";

interface InputProps extends ComponentPropsWithRef<"input"> {
  label?: string;
  error?: string;
}

export function Input({
  label,
  error,
  id,
  className,
  ref,
  ...props
}: InputProps) {
  const generatedId = useId();
  const inputId = id ?? generatedId;

  return (
    <div className="w-full">
      {label !== undefined && (
        <label htmlFor={inputId} className="mb-1 block text-sm text-slate-400">
          {label}
        </label>
      )}
      <input
        ref={ref}
        id={inputId}
        className={clsx(
          "w-full rounded-md border bg-surface-2 px-3 py-2 text-sm text-slate-50 placeholder-slate-500",
          "focus:outline-none focus:ring-1",
          error
            ? "border-loss focus:border-loss focus:ring-loss"
            : "border-surface-3 focus:border-brand-500 focus:ring-brand-500",
          className,
        )}
        aria-invalid={error ? true : undefined}
        {...props}
      />
      {error && <p className="mt-1 text-xs text-loss">{error}</p>}
    </div>
  );
}
