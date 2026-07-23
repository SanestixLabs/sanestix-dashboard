// Domain types for Sanestix OS — Phase 1 modules (Finance, Projects, CRM)
// These mirror the shape the FastAPI backend is expected to return per
// Sanestix-OS-Roadmap.md §1.5 (Executive Dashboard, real data from
// Finance + Projects + CRM). Swap `lib/data.ts` for real fetch calls
// against these same shapes when the backend ships.

export type TrendDirection = "up" | "down" | "flat";

export interface KpiCard {
  id: string;
  label: string;
  value: string;
  unit?: string;
  delta?: string;
  trend?: TrendDirection;
  tone?: "primary" | "neutral" | "success" | "warning" | "error";
  sourceModule: "finance" | "projects" | "crm";
}

export interface RevenuePoint {
  month: string;
  revenue: number;
  expenses: number;
}

export interface CashFlowPoint {
  month: string;
  inflow: number;
  outflow: number;
  net: number;
}

export interface FunnelStage {
  stage: string;
  count: number;
}

export interface ProjectStatusSlice {
  status: "On Track" | "At Risk" | "Delayed" | "Completed";
  count: number;
}

export type ActivityKind =
  | "invoice_due"
  | "invoice_paid"
  | "task_overdue"
  | "project_delay"
  | "lead_new"
  | "meeting_booked";

export interface ActivityItem {
  id: string;
  kind: ActivityKind;
  title: string;
  detail: string;
  timestamp: string; // relative label, e.g. "2m ago"
  module: "finance" | "projects" | "crm";
}

export interface DashboardData {
  kpis: KpiCard[];
  revenueTrend: RevenuePoint[];
  cashFlow: CashFlowPoint[];
  salesFunnel: FunnelStage[];
  projectStatus: ProjectStatusSlice[];
  activity: ActivityItem[];
  generatedAt: string;
}

// ---------------------------------------------------------------------------
// Transactions + Invoices — the raw ledger behind the Overview KPIs/charts.
// ---------------------------------------------------------------------------

export type TransactionKind = "revenue" | "expense";

export interface Transaction {
  id: string;
  occurredOn: string;
  kind: TransactionKind;
  category: string | null;
  amount: number;
  note: string | null;
  createdByName: string | null;
}

export type InvoiceStatus = "outstanding" | "paid" | "overdue";

export interface Invoice {
  id: string;
  clientName: string;
  amount: number;
  status: InvoiceStatus;
  dueDate: string;
  createdByName: string | null;
}

// ---------------------------------------------------------------------------
// Founder loans + profit distribution ("loan recovery" / "profit split")
// ---------------------------------------------------------------------------

export interface Founder {
  id: string;
  fullName: string | null;
}

export type LoanDirection = "loan_in" | "repayment_out";

export interface LoanEntry {
  id: string;
  founderId: string;
  founderName: string | null;
  occurredOn: string;
  description: string;
  direction: LoanDirection;
  amount: number;
}

export interface LoanBalance {
  founderId: string;
  founderName: string | null;
  totalLoaned: number;
  totalRepaid: number;
  outstanding: number;
}

export interface ProfitDistribution {
  id: string;
  periodMonth: string;
  grossProfit: number;
  capitalReserve: number;
  loanRepayment: number;
  distributableProfit: number;
  charityPct: number;
  charityAmount: number;
  perFounderAmount: number;
  note: string | null;
  createdAt: string;
}

export interface ProfitSplitSuggestion {
  periodMonth: string;
  grossProfit: number;
  outstandingLoanBalance: number;
}
