import Link from "next/link";
import { Download, Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { KpiCardView } from "@/components/dashboard/kpi-card";
import { RevenueTrendChart } from "@/components/dashboard/revenue-trend-chart";
import { CashFlowChart } from "@/components/dashboard/cash-flow-chart";
import { SalesFunnelChart } from "@/components/dashboard/sales-funnel-chart";
import { ProjectProgressChart } from "@/components/dashboard/project-progress-chart";
import { ActivityFeed } from "@/components/dashboard/activity-feed";
import { getDashboardData } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const data = await getDashboardData();

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Executive Dashboard"]}>
      <div className="flex items-end justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
            Executive Dashboard
          </h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Live data from Finance, Projects &amp; CRM — updated{" "}
            {new Date(data.generatedAt).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
        </div>
        <div className="flex gap-3">
          <Link
            href="/api/export/finance"
            className="hairline flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <Download size={14} />
            Export
          </Link>
          <Link
            href="/finance/transactions"
            className="flex items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            <Plus size={14} />
            New Action
          </Link>
        </div>
      </div>

      {/* KPI bento grid */}
      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        {data.kpis.map((kpi) => (
          <KpiCardView key={kpi.id} kpi={kpi} />
        ))}
      </div>

      {/* Revenue trend + activity feed */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <RevenueTrendChart data={data.revenueTrend} />
        <ActivityFeed items={data.activity} />
      </div>

      {/* Cash flow, funnel, project progress */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <CashFlowChart data={data.cashFlow} />
        <SalesFunnelChart data={data.salesFunnel} />
        <ProjectProgressChart data={data.projectStatus} />
      </div>
    </DashboardShell>
  );
}
