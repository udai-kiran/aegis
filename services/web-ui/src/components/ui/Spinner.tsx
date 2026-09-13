import { LoaderCircle } from "lucide-react";
import clsx from "clsx";

type SpinnerSize = "sm" | "md" | "lg";

interface SpinnerProps {
  size?: SpinnerSize;
  className?: string;
}

const sizeClasses: Record<SpinnerSize, string> = {
  sm: "size-3",
  md: "size-5",
  lg: "size-8",
};

export function Spinner({ size = "md", className }: SpinnerProps) {
  return (
    <LoaderCircle
      className={clsx(
        "animate-spin text-current",
        sizeClasses[size],
        className,
      )}
      aria-label="Loading"
    />
  );
}
