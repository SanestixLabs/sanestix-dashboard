#!/usr/bin/env bash
# Sanestix — build out the Reports section (Finance + Projects + CRM in one view)
# Run from the ROOT of your repo on the VPS.
set -e

mkdir -p src/app/reports src/app/api/export/reports

echo "Writing src/app/reports/page.tsx..."
cat > src/app/reports/page.tsx << 'REPORTS_PAGE_EOF'
import Link from "next/link";
import { ArrowRight, Download } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { KpiCardView } from "@/components/dashboard/kpi-card";
import { RevenueTrendChart } from "@/components/dashboard/revenue-trend-chart";
import { CashFlowChart } from "@/components/dashboard/cash-flow-chart";
import { ProjectProgressChart } from "@/components/dashboard/project-progress-chart";
import { SalesFunnelChart } from "@/components/dashboard/sales-funnel-chart";
import { formatCurrency, formatRelativeDate } from "@/lib/utils";
import {
  getFinanceData,
  getProjectsData,
  getCrmData,
  getInvoices,
  getCrmLeads,
  getProjects,
} from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

type AgingBucket = "Current" | "1-30 days" | "31-60 days" | "60+ days";
const AGING_ORDER: AgingBucket[] = ["Current", "1-30 days", "31-60 days", "60+ days"];

function agingBucket(dueDate: string): AgingBucket {
  const { daysUntil } = formatRelativeDate(dueDate);
  if (daysUntil >= 0) return "Current";
  const overdueDays = Math.abs(daysUntil);
  if (overdueDays <= 30) return "1-30 days";
  if (overdueDays <= 60) return "31-60 days";
  return "60+ days";
}

export default async function ReportsPage() {
  const [finance, projectsData, crm, invoices, leads, projects] = await Promise.all([
    getFinanceData(),
    getProjectsData(),
    getCrmData(),
    getInvoices(),
    getCrmLeads(),
    getProjects(),
  ]);

  const hasTrend = finance.revenueTrend.length > 0;

  // --- Invoice aging -------------------------------------------------------
  const unpaidInvoices = invoices.filter((invoice) => invoice.status !== "paid");
  const agingBuckets = AGING_ORDER.map((bucket) => {
    const rows = unpaidInvoices.filter((invoice) => agingBucket(invoice.dueDate) === bucket);
    return {
      bucket,
      count: rows.length,
      amount: rows.reduce((sum, invoice) => sum + invoice.amount, 0),
    };
  });
  const totalUnpaid = unpaidInvoices.reduce((sum, invoice) => sum + invoice.amount, 0);

  // --- Lead conversion -------------------------------------------------------
  const wonLeads = leads.filter((lead) => lead.stage === "won");
  const lostLeads = leads.filter((lead) => lead.stage === "lost");
  const decidedCount = wonLeads.length + lostLeads.length;
  const winRate = decidedCount > 0 ? (wonLeads.length / decidedCount) * 100 : 0;
  const totalWonValue = wonLeads.reduce((sum, lead) => sum + lead.value, 0);
  const avgDealValue = wonLeads.length > 0 ? totalWonValue / wonLeads.length : 0;

  // --- Project delivery -------------------------------------------------------
  const completedProjects = projects.filter((p) => p.status === "completed");
  const activeProjects = projects.filter((p) => p.status !== "completed");
  const totalTasks = projects.reduce((sum, p) => sum + p.taskCount, 0);
  const doneTasks = projects.reduce((sum, p) => sum + p.doneTaskCount, 0);
  const overdueTasks = projects.reduce((sum, p) => sum + p.overdueTaskCount, 0);
  const taskCompletionRate = totalTasks > 0 ? (doneTasks / totalTasks) * 100 : 0;

  const crossModuleMetrics: [string, string, string][] = [
    [
      "Task Completion Rate",
      totalTasks > 0 ? `${taskCompletionRate.toFixed(0)}%` : "-",
      taskCompletionRate >= 70 ? "text-success" : "text-warning",
    ],
    [
      "Overdue Tasks",
      String(overdueTasks),
      overdueTasks > 0 ? "text-error" : "text-success",
    ],
    [
      "Completed Projects",
      String(completedProjects.length),
      "text-on-surface",
    ],
    [
      "Lead Win Rate",
      decidedCount > 0 ? `${winRate.toFixed(0)}%` : "-",
      winRate >= 50 ? "text-success" : "text-warning",
    ],
    [
      "Avg. Won Deal",
      avgDealValue > 0 ? formatCurrency(avgDealValue, { compact: true }) : "-",
      "text-primary",
    ],
  ];

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Reports"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="font-mono-data text-[11px] uppercase tracking-wider text-primary">
            Cross-Module
          </p>
          <h1 className="mt-1 text-[28px] font-bold tracking-tight text-on-surface">
            Reports
          </h1>
          <p className="mt-2 max-w-2xl text-[13px] leading-6 text-on-surface-variant">
            Monthly revenue, invoice aging, project delivery, and CRM conversion — one
            operational view across Finance, Projects, and CRM.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link
            href="/api/export/finance"
            className="inline-flex w-fit items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <Download size={14} />
            Finance CSV
          </Link>
          <Link
            href="/api/export/reports"
            className="inline-flex w-fit items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <Download size={14} />
            Projects &amp; CRM CSV
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {finance.kpis.map((kpi) => (
          <KpiCardView key={kpi.id} kpi={kpi} />
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {crossModuleMetrics.map(([label, value, tone]) => (
          <Card key={label} className="p-4">
            <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
              {label}
            </p>
            <p className={`mt-2 text-[22px] font-bold tracking-tight ${tone}`}>{value}</p>
          </Card>
        ))}
      </div>

      {hasTrend ? (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <RevenueTrendChart data={finance.revenueTrend} />
          <CashFlowChart data={finance.cashFlow} />
        </div>
      ) : (
        <div className="hairline border p-6 text-[13px] text-on-surface-variant">
          No finance transactions yet — add rows to{" "}
          <code className="font-mono-data">finance_transactions</code> in Supabase to see
          revenue and cash-flow trends here.
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <ProjectProgressChart data={projectsData.projectStatus} />
        <SalesFunnelChart data={crm.salesFunnel} />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-6">
          <div className="flex items-start justify-between">
            <div>
              <CardTitle>Invoice Aging</CardTitle>
              <CardDescription>Unpaid invoices grouped by days past due.</CardDescription>
            </div>
            <Link
              href="/finance/invoices"
              className="inline-flex items-center gap-1 text-[11px] font-mono-data uppercase tracking-wider text-primary"
            >
              View invoices
              <ArrowRight size={12} />
            </Link>
          </div>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[420px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Bucket</th>
                  <th className="pb-2 pr-4 text-right">Invoices</th>
                  <th className="pb-2 text-right">Amount</th>
                </tr>
              </thead>
              <tbody>
                {agingBuckets.map(({ bucket, count, amount }) => (
                  <tr key={bucket} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4">{bucket}</td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">{count}</td>
                    <td
                      className={`py-2.5 text-right font-mono-data ${
                        bucket === "Current" ? "text-on-surface" : "text-warning"
                      }`}
                    >
                      {formatCurrency(amount)}
                    </td>
                  </tr>
                ))}
                <tr>
                  <td className="pt-3 pr-4 font-semibold">Total unpaid</td>
                  <td className="pt-3 pr-4 text-right font-mono-data font-semibold">
                    {unpaidInvoices.length}
                  </td>
                  <td className="pt-3 text-right font-mono-data font-semibold">
                    {formatCurrency(totalUnpaid)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </Card>

        <Card className="p-6">
          <CardTitle>Delivery &amp; Conversion Detail</CardTitle>
          <CardDescription>Project throughput and pipeline outcomes.</CardDescription>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Active projects</span>
              <span className="font-mono-data">{activeProjects.length}</span>
            </div>
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Tasks completed / total</span>
              <span className="font-mono-data">
                {doneTasks} / {totalTasks}
              </span>
            </div>
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Won leads</span>
              <span className="font-mono-data text-success">{wonLeads.length}</span>
            </div>
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Lost leads</span>
              <span className="font-mono-data text-error">{lostLeads.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-on-surface-variant">Total won pipeline value</span>
              <span className="font-mono-data text-success">
                {formatCurrency(totalWonValue)}
              </span>
            </div>
          </div>
        </Card>
      </div>

      <Card className="flex flex-col items-start justify-between gap-3 p-6 sm:flex-row sm:items-center">
        <div>
          <CardTitle>Need the full audit-ready ledger?</CardTitle>
          <CardDescription>
            Founder balances, distributions, and register counts live on the Finance
            Reports page.
          </CardDescription>
        </div>
        <Link
          href="/finance/reports"
          className="inline-flex w-fit shrink-0 items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          Open Finance Reports
          <ArrowRight size={14} />
        </Link>
      </Card>
    </DashboardShell>
  );
}
REPORTS_PAGE_EOF

echo "Writing src/app/api/export/reports/route.ts..."
cat > src/app/api/export/reports/route.ts << 'REPORTS_EXPORT_EOF'
import { getProjects, getCrmLeads, getCrmCompanies } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function csvRow(values: Array<string | number | null | undefined>) {
  return values.map(csvCell).join(",");
}

export async function GET() {
  try {
    const [projects, leads, companies] = await Promise.all([
      getProjects(),
      getCrmLeads(),
      getCrmCompanies(),
    ]);

    const rows = [
      csvRow(["Section", "Date", "Status/Stage", "Name", "Client/Company", "Detail", "Value PKR"]),
      ...projects.map((project) =>
        csvRow([
          "Projects",
          project.createdAt,
          project.status,
          project.name,
          project.clientName,
          `${project.doneTaskCount}/${project.taskCount} tasks done, ${project.overdueTaskCount} overdue`,
          project.budget ?? "",
        ])
      ),
      ...leads.map((lead) =>
        csvRow([
          "CRM Leads",
          lead.createdAt,
          lead.stage,
          lead.title,
          lead.companyName,
          lead.ownerName ? `Owner: ${lead.ownerName}` : "",
          lead.value,
        ])
      ),
      ...companies.map((company) =>
        csvRow([
          "CRM Companies",
          company.createdAt,
          "",
          company.name,
          company.industry,
          `${company.contactCount} contacts, ${company.leadCount} leads`,
          "",
        ])
      ),
    ];

    return new Response(rows.join("\n"), {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="sanestix-reports-export.csv"',
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown export error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
REPORTS_EXPORT_EOF

echo ""
echo "Done writing files. Now rebuild and restart:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
echo ""
echo "Or if you run it outside Docker (pm2 / systemd):"
echo "  npm run build && pm2 restart sanestix-dashboard   # (or your process name)"
