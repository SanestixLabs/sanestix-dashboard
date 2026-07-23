import { cn } from "@/lib/utils";

type Tone = "primary" | "neutral" | "success" | "warning" | "error";

const toneClasses: Record<Tone, string> = {
  primary: "bg-primary/10 border-primary/25 text-primary",
  neutral: "bg-surface-container-high border-outline-variant text-on-surface-variant",
  success: "bg-success/10 border-success/25 text-success",
  warning: "bg-warning/10 border-warning/25 text-warning",
  error: "bg-error/10 border-error/25 text-error",
};

export function StatusPill({
  children,
  tone = "neutral",
  className,
}: {
  children: React.ReactNode;
  tone?: Tone;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 border px-2 py-1 text-[10px] font-mono-data uppercase tracking-wider",
        toneClasses[tone],
        className
      )}
    >
      {children}
    </span>
  );
}
