"use client";

import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import type { FunnelStage } from "@/lib/types";

export function SalesFunnelChart({ data }: { data: FunnelStage[] }) {
  const max = data[0]?.count ?? 1;
  const conversion = ((data[data.length - 1].count / data[0].count) * 100).toFixed(1);

  return (
    <Card className="flex flex-col p-6">
      <div className="mb-6 flex items-start justify-between">
        <div>
          <CardTitle>Sales Funnel</CardTitle>
          <CardDescription>Lead progression this quarter</CardDescription>
        </div>
        <StatusPill tone="neutral">CRM</StatusPill>
      </div>

      <div className="flex-1 space-y-3">
        {data.map((stage, i) => {
          const widthPct = Math.max((stage.count / max) * 100, 6);
          return (
            <div key={stage.stage}>
              <div className="mb-1 flex items-center justify-between text-[11px]">
                <span className="text-on-surface-variant">{stage.stage}</span>
                <span className="font-mono-data text-on-surface">{stage.count}</span>
              </div>
              <div className="h-2 w-full bg-surface-container-high">
                <div
                  className="h-2 bg-primary transition-all"
                  style={{
                    width: `${widthPct}%`,
                    opacity: 1 - i * 0.12,
                  }}
                />
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-5 border-t border-outline-variant pt-3 text-[11px] text-on-surface-variant">
        Lead → Closed Won conversion:{" "}
        <span className="font-mono-data font-semibold text-primary">{conversion}%</span>
      </div>
    </Card>
  );
}
