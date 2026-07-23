import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { KpiCardView } from "@/components/dashboard/kpi-card";
import { RevenueTrendChart } from "@/components/dashboard/revenue-trend-chart";
import { CashFlowChart } from "@/components/dashboard/cash-flow-chart";
import { getFinanceData } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function FinancePage() {
  const data = await getFinanceData();
  const hasTrend = data.revenueTrend.length > 0;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Finance</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Revenue, expenses and invoices — live from Supabase.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {data.kpis.map((kpi) => (
          <KpiCardView key={kpi.id} kpi={kpi} />
        ))}
      </div>

      {hasTrend ? (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <RevenueTrendChart data={data.revenueTrend} />
          <CashFlowChart data={data.cashFlow} />
        </div>
      ) : (
        <div className="hairline border p-6 text-[13px] text-on-surface-variant">
          No finance transactions yet — add rows to{" "}
          <code className="font-mono-data">finance_transactions</code> in Supabase to see
          charts here.
        </div>
      )}
    </DashboardShell>
  );
}
