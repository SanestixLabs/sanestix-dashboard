import type { DashboardData } from "./types";
import { getFinanceData } from "./supabase/queries";

// -----------------------------------------------------------------------
// STATUS (update this comment as modules go live):
//   Finance   → REAL, from Supabase (finance_transactions + invoices)
//   Projects  → mock, still hardcoded below
//   CRM       → mock, still hardcoded below
//
// When Projects/CRM get their own tables, add a getProjectsData() /
// getCrmData() next to getFinanceData() in lib/supabase/queries.ts and
// merge them below the same way Finance is merged now. No component
// outside this file needs to change — they all consume DashboardData.
// -----------------------------------------------------------------------

const MOCK_DASHBOARD_DATA: DashboardData = {
  generatedAt: new Date().toISOString(),
  kpis: [
    {
      id: "revenue-mtd",
      label: "Revenue (MTD)",
      value: "48.2",
      unit: "K",
      delta: "+12.4% vs last month",
      trend: "up",
      tone: "primary",
      sourceModule: "finance",
    },
    {
      id: "outstanding-invoices",
      label: "Outstanding Invoices",
      value: "9",
      delta: "$18.6K overdue",
      trend: "flat",
      tone: "warning",
      sourceModule: "finance",
    },
    {
      id: "active-projects",
      label: "Active Projects",
      value: "14",
      delta: "3 due this week",
      trend: "flat",
      tone: "neutral",
      sourceModule: "projects",
    },
    {
      id: "overdue-tasks",
      label: "Overdue Tasks",
      value: "6",
      delta: "+2 since Monday",
      trend: "up",
      tone: "error",
      sourceModule: "projects",
    },
    {
      id: "open-leads",
      label: "Open Leads",
      value: "31",
      delta: "+5 this week",
      trend: "up",
      tone: "primary",
      sourceModule: "crm",
    },
    {
      id: "pipeline-value",
      label: "Pipeline Value",
      value: "126",
      unit: "K",
      delta: "8 in final stage",
      trend: "up",
      tone: "success",
      sourceModule: "crm",
    },
  ],
  revenueTrend: [
    { month: "Feb", revenue: 31200, expenses: 21400 },
    { month: "Mar", revenue: 33800, expenses: 22100 },
    { month: "Apr", revenue: 29600, expenses: 20800 },
    { month: "May", revenue: 37450, expenses: 23950 },
    { month: "Jun", revenue: 41200, expenses: 25100 },
    { month: "Jul", revenue: 48200, expenses: 26700 },
  ],
  cashFlow: [
    { month: "Feb", inflow: 34500, outflow: 24100, net: 10400 },
    { month: "Mar", inflow: 36200, outflow: 25300, net: 10900 },
    { month: "Apr", inflow: 30100, outflow: 23600, net: 6500 },
    { month: "May", inflow: 39800, outflow: 26200, net: 13600 },
    { month: "Jun", inflow: 43900, outflow: 27400, net: 16500 },
    { month: "Jul", inflow: 50100, outflow: 28900, net: 21200 },
  ],
  salesFunnel: [
    { stage: "Leads", count: 142 },
    { stage: "Contacted", count: 96 },
    { stage: "Qualified", count: 58 },
    { stage: "Proposal", count: 27 },
    { stage: "Closed Won", count: 12 },
  ],
  projectStatus: [
    { status: "On Track", count: 8 },
    { status: "At Risk", count: 3 },
    { status: "Delayed", count: 2 },
    { status: "Completed", count: 5 },
  ],
  activity: [
    {
      id: "act-1",
      kind: "invoice_due",
      title: "Invoice #INV-2291 due tomorrow",
      detail: "Northwind Logistics — $6,400 net-15",
      timestamp: "12m ago",
      module: "finance",
    },
    {
      id: "act-2",
      kind: "task_overdue",
      title: "Task overdue — API rate limiting",
      detail: "Project: Atlas Migration · assigned to D. Farooq",
      timestamp: "38m ago",
      module: "projects",
    },
    {
      id: "act-3",
      kind: "lead_new",
      title: "New lead — Marwaa Memorials (Enterprise)",
      detail: "Inbound via website form, routed to Sales",
      timestamp: "1h ago",
      module: "crm",
    },
    {
      id: "act-4",
      kind: "invoice_paid",
      title: "Payment received — INV-2287",
      detail: "Cedar & Co — $12,900 cleared",
      timestamp: "2h ago",
      module: "finance",
    },
    {
      id: "act-5",
      kind: "project_delay",
      title: "Project delayed — Client Portal v2",
      detail: "Slipped 4 days, blocked on design sign-off",
      timestamp: "3h ago",
      module: "projects",
    },
    {
      id: "act-6",
      kind: "meeting_booked",
      title: "Meeting booked — Fintoku demo",
      detail: "Thu 3:00 PM with N. Aslam",
      timestamp: "5h ago",
      module: "crm",
    },
  ],
};

export async function getDashboardData(): Promise<DashboardData> {
  const mockFinanceKpiIds = new Set(["revenue-mtd", "outstanding-invoices"]);
  const nonFinanceKpis = MOCK_DASHBOARD_DATA.kpis.filter((k) => !mockFinanceKpiIds.has(k.id));

  const finance = await getFinanceData();
  return {
    ...MOCK_DASHBOARD_DATA,
    generatedAt: new Date().toISOString(),
    kpis: [...finance.kpis, ...nonFinanceKpis],
    revenueTrend: finance.revenueTrend.length ? finance.revenueTrend : MOCK_DASHBOARD_DATA.revenueTrend,
    cashFlow: finance.cashFlow.length ? finance.cashFlow : MOCK_DASHBOARD_DATA.cashFlow,
  };
}
