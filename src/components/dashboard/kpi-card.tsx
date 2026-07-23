import { TrendingUp, TrendingDown, Minus } from "lucide-react";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { KpiCard as KpiCardType } from "@/lib/types";

const toneTextClass: Record<NonNullable<KpiCardType["tone"]>, string> = {
  primary: "text-primary",
  neutral: "text-on-surface",
  success: "text-success",
  warning: "text-warning",
  error: "text-error",
};

const moduleLabel: Record<KpiCardType["sourceModule"], string> = {
  finance: "Finance",
  projects: "Projects",
  crm: "CRM",
};

export function KpiCardView({ kpi }: { kpi: KpiCardType }) {
  const tone = kpi.tone ?? "neutral";
  const TrendIcon =
    kpi.trend === "up" ? TrendingUp : kpi.trend === "down" ? TrendingDown : Minus;

  return (
    <Card className="group flex flex-col justify-between p-4 transition-colors hover:border-primary/50">
      <div>
        <div className="flex items-center justify-between">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            {kpi.label}
          </p>
          <span className="text-[9px] font-mono-data uppercase tracking-wider text-on-surface-variant/40">
            {moduleLabel[kpi.sourceModule]}
          </span>
        </div>
        <div className="mt-2 flex items-baseline gap-1">
          <span
            className={cn(
              "text-[28px] font-bold leading-none tracking-tight",
              toneTextClass[tone]
            )}
          >
            {kpi.value}
          </span>
          {kpi.unit && (
            <span
              className={cn(
                "text-[13px] font-mono-data opacity-80",
                toneTextClass[tone]
              )}
            >
              {kpi.unit}
            </span>
          )}
        </div>
      </div>
      {kpi.delta && (
        <div className={cn("mt-4 flex items-center gap-1 text-[10px]", toneTextClass[tone])}>
          <TrendIcon size={12} />
          <span className="font-mono-data">{kpi.delta}</span>
        </div>
      )}
    </Card>
  );
}
