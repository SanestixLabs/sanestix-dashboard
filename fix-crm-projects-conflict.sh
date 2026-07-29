#!/usr/bin/env bash
# Fix: restore CRM exports lost when apply-projects-module.sh overwrote
# lib/types.ts, lib/supabase/queries.ts, lib/data.ts.
# Run from the ROOT of your repo (/opt/sanestix-dashboard or wherever it lives).
set -e

mkdir -p src/lib/supabase

echo "1/3 -- Restoring src/lib/types.ts (CRM + Projects types)..."
cat > "src/lib/types.ts" << 'SANESTIX_EOF'
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
  proofUrl: string | null;
  createdByName: string | null;
}

export type InvoiceStatus = "outstanding" | "paid" | "overdue";

export interface Invoice {
  id: string;
  clientName: string;
  amount: number;
  status: InvoiceStatus;
  dueDate: string;
  proofUrl: string | null;
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

// ---------------------------------------------------------------------------
// Phase 2 registers — Vendors, Subscriptions, Assets, Debts, Employees
// ---------------------------------------------------------------------------

export type VendorStatus = "active" | "inactive";

export interface Vendor {
  id: string;
  name: string;
  category: string | null;
  contactPerson: string | null;
  contactEmail: string | null;
  paymentTerms: string | null;
  status: VendorStatus;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type BillingCycle = "monthly" | "annual";
export type SubscriptionStatus = "active" | "cancelled";

export interface Subscription {
  id: string;
  vendorName: string;
  cost: number;
  billingCycle: BillingCycle;
  renewalDate: string | null;
  owner: string | null;
  status: SubscriptionStatus;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type AssetCondition = "new" | "good" | "fair" | "poor" | "disposed";

export interface Asset {
  id: string;
  name: string;
  purchaseDate: string;
  cost: number;
  owner: string | null;
  condition: AssetCondition;
  serialNumber: string | null;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type DebtStatus = "outstanding" | "paid" | "overdue";

export interface Debt {
  id: string;
  counterparty: string;
  principal: number;
  paidAmount: number;
  remainingBalance: number;
  dueDate: string | null;
  status: DebtStatus;
  notes: string | null;
  proofUrl: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type EmployeeStatus = "active" | "inactive";

export interface Employee {
  id: string;
  fullName: string;
  role: string | null;
  salary: number | null;
  startDate: string | null;
  status: EmployeeStatus;
  payDay: number | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Upcoming payments — combined view of money due out (debts, subscription
// renewals) vs. money due in (unpaid invoices), for the Finance overview.
// ---------------------------------------------------------------------------

export type UpcomingPaymentDirection = "due" | "to_receive";
export type UpcomingPaymentSource = "invoice" | "debt" | "subscription" | "employee";

export interface UpcomingPayment {
  id: string;
  direction: UpcomingPaymentDirection;
  source: UpcomingPaymentSource;
  label: string;
  amount: number;
  dueDate: string;
  overdue: boolean;
}

// ---------------------------------------------------------------------------
// Employee salary payments — payroll history with optional proof-of-payment
// image, so each payday can be marked paid and audited later.
// ---------------------------------------------------------------------------

export interface EmployeePayment {
  id: string;
  employeeId: string;
  employeeName: string | null;
  amount: number;
  payPeriod: string; // first day of the month this payment covers, e.g. "2026-07-01"
  paidOn: string;
  proofUrl: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// CRM — Companies, Contacts, Leads (pipeline), activity log, follow-up tasks.
// A "won" lead auto-creates a draft Project (see app/crm/actions.ts), which
// is the real cross-module link the roadmap calls for.
// ---------------------------------------------------------------------------

export interface CrmCompany {
  id: string;
  name: string;
  industry: string | null;
  website: string | null;
  notes: string | null;
  contactCount: number;
  leadCount: number;
  createdByName: string | null;
  createdAt: string;
}

export interface CrmContact {
  id: string;
  companyId: string | null;
  companyName: string | null;
  fullName: string;
  email: string | null;
  phone: string | null;
  title: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}

export type LeadStage = "new" | "contacted" | "qualified" | "proposal" | "won" | "lost";

export const LEAD_STAGES: { value: LeadStage; label: string }[] = [
  { value: "new", label: "New" },
  { value: "contacted", label: "Contacted" },
  { value: "qualified", label: "Qualified" },
  { value: "proposal", label: "Proposal" },
  { value: "won", label: "Won" },
  { value: "lost", label: "Lost" },
];

export interface CrmLead {
  id: string;
  title: string;
  companyId: string | null;
  companyName: string | null;
  contactId: string | null;
  contactName: string | null;
  contactEmail: string | null;
  stage: LeadStage;
  value: number;
  source: string | null;
  ownerId: string | null;
  ownerName: string | null;
  expectedCloseDate: string | null;
  notes: string | null;
  convertedProjectId: string | null;
  openTaskCount: number;
  overdueTaskCount: number;
  createdByName: string | null;
  createdAt: string;
  updatedAt: string;
}

export type LeadActivityKind = "note" | "call" | "email" | "meeting" | "stage_change";

export interface CrmLeadActivity {
  id: string;
  leadId: string;
  kind: LeadActivityKind;
  content: string;
  createdByName: string | null;
  createdAt: string;
}

export interface CrmLeadTask {
  id: string;
  leadId: string;
  leadTitle: string | null;
  title: string;
  dueDate: string;
  done: boolean;
  overdue: boolean;
  createdByName: string | null;
  createdAt: string;
}

// ---------------------------------------------------------------------------
// Projects — minimal real table. Grows later (tasks, members, comments)
// without changing this shape; a project can optionally trace back to the
// lead that became it.
// ---------------------------------------------------------------------------

export type ProjectRowStatus = "on_track" | "at_risk" | "delayed" | "completed";

export interface Project {
  id: string;
  name: string;
  clientName: string | null;
  companyId: string | null;
  companyName: string | null;
  status: ProjectRowStatus;
  sourceLeadId: string | null;
  sourceLeadTitle: string | null;
  notes: string | null;
  createdByName: string | null;
  createdAt: string;
}
SANESTIX_EOF

echo "2/3 -- Restoring src/lib/supabase/queries.ts (CRM + Projects queries)..."
cat > "src/lib/supabase/queries.ts" << 'SANESTIX_EOF'
import { createClient } from "@/lib/supabase/server";
import { formatCurrency } from "@/lib/utils";
import type {
  Asset,
  CashFlowPoint,
  CrmCompany,
  CrmContact,
  CrmLead,
  CrmLeadActivity,
  CrmLeadTask,
  Debt,
  Employee,
  EmployeePayment,
  Founder,
  FunnelStage,
  Invoice,
  KpiCard,
  LoanBalance,
  LoanEntry,
  Project,
  ProfitDistribution,
  ProjectStatusSlice,
  RevenuePoint,
  Subscription,
  Transaction,
  UpcomingPayment,
  Vendor,
} from "@/lib/types";

const MONTH_LABEL = new Intl.DateTimeFormat("en-US", { month: "short" });

/**
 * Real Finance data, pulled from Supabase (finance_transactions + invoices).
 * This is the one module wired to a real database so far — Projects and CRM
 * are still mock data in lib/data.ts until those modules are built.
 */
export async function getFinanceData(): Promise<{
  kpis: KpiCard[];
  revenueTrend: RevenuePoint[];
  cashFlow: CashFlowPoint[];
}> {
  const supabase = await createClient();

  const [{ data: transactions, error: txError }, { data: invoices, error: invError }] =
    await Promise.all([
      supabase
        .from("finance_transactions")
        .select("occurred_on, kind, amount")
        .order("occurred_on", { ascending: true }),
      supabase.from("invoices").select("amount, status"),
    ]);

  if (txError) throw new Error(`Failed to load finance_transactions: ${txError.message}`);
  if (invError) throw new Error(`Failed to load invoices: ${invError.message}`);

  // Group transactions by month (YYYY-MM) → { revenue, expenses }
  const byMonth = new Map<string, { revenue: number; expenses: number }>();
  for (const row of transactions ?? []) {
    const key = row.occurred_on.slice(0, 7); // "2026-07"
    const bucket = byMonth.get(key) ?? { revenue: 0, expenses: 0 };
    if (row.kind === "revenue") bucket.revenue += Number(row.amount);
    else bucket.expenses += Number(row.amount);
    byMonth.set(key, bucket);
  }

  const sortedMonths = [...byMonth.keys()].sort().slice(-6);

  const revenueTrend: RevenuePoint[] = sortedMonths.map((key) => {
    const { revenue, expenses } = byMonth.get(key)!;
    const date = new Date(`${key}-01T00:00:00Z`);
    return { month: MONTH_LABEL.format(date), revenue, expenses };
  });

  const cashFlow: CashFlowPoint[] = sortedMonths.map((key) => {
    const { revenue, expenses } = byMonth.get(key)!;
    const date = new Date(`${key}-01T00:00:00Z`);
    return {
      month: MONTH_LABEL.format(date),
      inflow: revenue,
      outflow: expenses,
      net: revenue - expenses,
    };
  });

  const currentMonthKey = sortedMonths[sortedMonths.length - 1];
  const previousMonthKey = sortedMonths[sortedMonths.length - 2];
  const currentRevenue = currentMonthKey ? byMonth.get(currentMonthKey)!.revenue : 0;
  const previousRevenue = previousMonthKey ? byMonth.get(previousMonthKey)!.revenue : 0;
  const revenueDeltaPct =
    previousRevenue > 0 ? ((currentRevenue - previousRevenue) / previousRevenue) * 100 : 0;

  const currentExpenses = currentMonthKey ? byMonth.get(currentMonthKey)!.expenses : 0;
  const netProfitMtd = currentRevenue - currentExpenses;

  const totalRevenueAllTime = (transactions ?? [])
    .filter((t) => t.kind === "revenue")
    .reduce((sum, t) => sum + Number(t.amount), 0);
  const totalExpensesAllTime = (transactions ?? [])
    .filter((t) => t.kind === "expense")
    .reduce((sum, t) => sum + Number(t.amount), 0);
  const netProfitAllTime = totalRevenueAllTime - totalExpensesAllTime;

  const outstandingInvoices = (invoices ?? []).filter(
    (inv) => inv.status === "outstanding" || inv.status === "overdue"
  );
  const overdueTotal = (invoices ?? [])
    .filter((inv) => inv.status === "overdue")
    .reduce((sum, inv) => sum + Number(inv.amount), 0);

  const kpis: KpiCard[] = [
    {
      id: "revenue-mtd",
      label: "Revenue (MTD)",
      value: formatCurrency(currentRevenue, { compact: true }),
      delta: previousMonthKey
        ? `${revenueDeltaPct >= 0 ? "+" : ""}${revenueDeltaPct.toFixed(1)}% vs last month`
        : undefined,
      trend: revenueDeltaPct > 0 ? "up" : revenueDeltaPct < 0 ? "down" : "flat",
      tone: "primary",
      sourceModule: "finance",
    },
    {
      id: "net-profit-mtd",
      label: "Net Profit (MTD)",
      value: formatCurrency(netProfitMtd, { compact: true }),
      delta: `${formatCurrency(currentExpenses, { compact: true })} in expenses`,
      trend: netProfitMtd >= 0 ? "up" : "down",
      tone: netProfitMtd >= 0 ? "success" : "error",
      sourceModule: "finance",
    },
    {
      id: "net-profit-all-time",
      label: "Net Profit (All Time)",
      value: formatCurrency(netProfitAllTime, { compact: true }),
      delta: `${formatCurrency(totalRevenueAllTime, { compact: true })} total revenue`,
      trend: netProfitAllTime >= 0 ? "up" : "down",
      tone: netProfitAllTime >= 0 ? "success" : "error",
      sourceModule: "finance",
    },
    {
      id: "outstanding-invoices",
      label: "Outstanding Invoices",
      value: String(outstandingInvoices.length),
      delta:
        overdueTotal > 0 ? `${formatCurrency(overdueTotal, { compact: true })} overdue` : undefined,
      trend: "flat",
      tone: overdueTotal > 0 ? "warning" : "success",
      sourceModule: "finance",
    },
  ];

  return { kpis, revenueTrend, cashFlow };
}

/**
 * Full transaction ledger (finance_transactions), newest first, joined with
 * the logging user's name where available.
 */
export async function getTransactions(): Promise<Transaction[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("finance_transactions")
    .select("id, occurred_on, kind, category, amount, note, proof_url, profiles(full_name)")
    .order("occurred_on", { ascending: false });

  if (error) throw new Error(`Failed to load finance_transactions: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      occurredOn: row.occurred_on,
      kind: row.kind,
      category: row.category,
      amount: Number(row.amount),
      note: row.note,
      proofUrl: row.proof_url,
      createdByName: profile?.full_name ?? null,
    };
  });
}

/**
 * Full invoice list, soonest due date first, joined with the creating
 * user's name where available.
 */
export async function getInvoices(): Promise<Invoice[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("invoices")
    .select("id, client_name, amount, status, due_date, proof_url, profiles(full_name)")
    .order("due_date", { ascending: true });

  if (error) throw new Error(`Failed to load invoices: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      clientName: row.client_name,
      amount: Number(row.amount),
      status: row.status,
      dueDate: row.due_date,
      proofUrl: row.proof_url,
      createdByName: profile?.full_name ?? null,
    };
  });
}

/**
 * All signed-up users, treated as the pool of co-founders for the loan
 * ledger and profit-split modules.
 */
export async function getFounders(): Promise<Founder[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name")
    .order("full_name", { ascending: true });

  if (error) throw new Error(`Failed to load profiles: ${error.message}`);

  return (data ?? []).map((row) => ({ id: row.id, fullName: row.full_name }));
}

/**
 * Full founder_loans ledger, newest first, joined with the founder's name.
 */
export async function getLoanLedger(): Promise<LoanEntry[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("founder_loans")
    .select("id, founder_id, occurred_on, description, direction, amount, profiles!founder_loans_founder_id_fkey(full_name)")
    .order("occurred_on", { ascending: false });

  if (error) throw new Error(`Failed to load founder_loans: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      founderId: row.founder_id,
      founderName: profile?.full_name ?? null,
      occurredOn: row.occurred_on,
      description: row.description,
      direction: row.direction,
      amount: Number(row.amount),
    };
  });
}

/**
 * Outstanding loan balance per founder: total loaned in minus total repaid.
 */
export async function getLoanBalances(): Promise<LoanBalance[]> {
  const [founders, ledger] = await Promise.all([getFounders(), getLoanLedger()]);

  return founders.map((founder) => {
    const entries = ledger.filter((entry) => entry.founderId === founder.id);
    const totalLoaned = entries
      .filter((e) => e.direction === "loan_in")
      .reduce((sum, e) => sum + e.amount, 0);
    const totalRepaid = entries
      .filter((e) => e.direction === "repayment_out")
      .reduce((sum, e) => sum + e.amount, 0);

    return {
      founderId: founder.id,
      founderName: founder.fullName,
      totalLoaned,
      totalRepaid,
      outstanding: totalLoaned - totalRepaid,
    };
  });
}

/**
 * Combined outstanding loan balance across all founders — used to prefill
 * the profit-split "loan repayment" suggestion.
 */
export async function getTotalOutstandingLoans(): Promise<number> {
  const balances = await getLoanBalances();
  return balances.reduce((sum, b) => sum + b.outstanding, 0);
}

/**
 * Profit distribution history, newest period first.
 */
export async function getProfitDistributions(): Promise<ProfitDistribution[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profit_distributions")
    .select(
      "id, period_month, gross_profit, capital_reserve, loan_repayment, distributable_profit, charity_pct, charity_amount, per_founder_amount, note, created_at"
    )
    .order("period_month", { ascending: false });

  if (error) throw new Error(`Failed to load profit_distributions: ${error.message}`);

  return (data ?? []).map((row) => ({
    id: row.id,
    periodMonth: row.period_month,
    grossProfit: Number(row.gross_profit),
    capitalReserve: Number(row.capital_reserve),
    loanRepayment: Number(row.loan_repayment),
    distributableProfit: Number(row.distributable_profit),
    charityPct: Number(row.charity_pct),
    charityAmount: Number(row.charity_amount),
    perFounderAmount: Number(row.per_founder_amount),
    note: row.note,
    createdAt: row.created_at,
  }));
}

// ---------------------------------------------------------------------------
// Phase 2 registers — Vendors, Subscriptions, Assets, Debts, Employees
// ---------------------------------------------------------------------------

/**
 * Full vendor list, newest first, joined with the logging user's name.
 */
export async function getVendors(): Promise<Vendor[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("vendors")
    .select(
      "id, name, category, contact_person, contact_email, payment_terms, status, notes, created_at, profiles(full_name)"
    )
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Failed to load vendors: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      name: row.name,
      category: row.category,
      contactPerson: row.contact_person,
      contactEmail: row.contact_email,
      paymentTerms: row.payment_terms,
      status: row.status,
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Full subscription register, soonest renewal first, joined with the
 * logging user's name.
 */
export async function getSubscriptions(): Promise<Subscription[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("subscriptions")
    .select(
      "id, vendor_name, cost, billing_cycle, renewal_date, owner, status, notes, proof_url, created_at, profiles(full_name)"
    )
    .order("renewal_date", { ascending: true, nullsFirst: false });

  if (error) throw new Error(`Failed to load subscriptions: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      vendorName: row.vendor_name,
      cost: Number(row.cost),
      billingCycle: row.billing_cycle,
      renewalDate: row.renewal_date,
      owner: row.owner,
      status: row.status,
      notes: row.notes,
      proofUrl: row.proof_url,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Full asset register, newest purchase first, joined with the logging
 * user's name.
 */
export async function getAssets(): Promise<Asset[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("assets")
    .select(
      "id, name, purchase_date, cost, owner, condition, serial_number, notes, proof_url, created_at, profiles(full_name)"
    )
    .order("purchase_date", { ascending: false });

  if (error) throw new Error(`Failed to load assets: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      name: row.name,
      purchaseDate: row.purchase_date,
      cost: Number(row.cost),
      owner: row.owner,
      condition: row.condition,
      serialNumber: row.serial_number,
      notes: row.notes,
      proofUrl: row.proof_url,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Full debts & liabilities register, soonest due date first, joined with
 * the logging user's name. remainingBalance is derived (principal - paid).
 */
export async function getDebts(): Promise<Debt[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("debts")
    .select(
      "id, counterparty, principal, paid_amount, due_date, status, notes, proof_url, created_at, profiles(full_name)"
    )
    .order("due_date", { ascending: true, nullsFirst: false });

  if (error) throw new Error(`Failed to load debts: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const principal = Number(row.principal);
    const paidAmount = Number(row.paid_amount);
    return {
      id: row.id,
      counterparty: row.counterparty,
      principal,
      paidAmount,
      remainingBalance: principal - paidAmount,
      dueDate: row.due_date,
      status: row.status,
      notes: row.notes,
      proofUrl: row.proof_url,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Full employee register, newest first, joined with the logging user's name.
 */
export async function getEmployees(): Promise<Employee[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("employees")
    .select(
      "id, full_name, role, salary, start_date, status, pay_day, notes, created_at, profiles!created_by(full_name)"
    )
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Failed to load employees: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      fullName: row.full_name,
      role: row.role,
      salary: row.salary === null ? null : Number(row.salary),
      startDate: row.start_date,
      status: row.status,
      payDay: row.pay_day === null ? null : Number(row.pay_day),
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Salary payment history, newest first, joined with the employee's name and
 * the logging user's name. Pass an employeeId to scope to one employee.
 */
export async function getEmployeePayments(employeeId?: string): Promise<EmployeePayment[]> {
  const supabase = await createClient();
  let query = supabase
    .from("employee_payments")
    .select(
      "id, employee_id, amount, pay_period, paid_on, proof_url, notes, created_at, employees(full_name), profiles!created_by(full_name)"
    )
    .order("paid_on", { ascending: false });

  if (employeeId) {
    query = query.eq("employee_id", employeeId);
  }

  const { data, error } = await query;

  if (error) throw new Error(`Failed to load employee_payments: ${error.message}`);

  return (data ?? []).map((row) => {
    const employee = Array.isArray(row.employees) ? row.employees[0] : row.employees;
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      employeeId: row.employee_id,
      employeeName: employee?.full_name ?? null,
      amount: Number(row.amount),
      payPeriod: row.pay_period,
      paidOn: row.paid_on,
      proofUrl: row.proof_url,
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Given a day-of-month (1-31) and a reference "today", returns the ISO date
 * of the next occurrence of that payday: this month if it hasn't passed
 * yet, otherwise next month. Days beyond a month's length (e.g. 31 in
 * February, or in April/June/Sept/Nov) are clamped to that month's last day.
 */
function nextPayDate(payDay: number, today: Date): string {
  const clamp = (year: number, monthIndex: number) => {
    const lastDayOfMonth = new Date(year, monthIndex + 1, 0).getDate();
    return Math.min(payDay, lastDayOfMonth);
  };

  const thisMonthDay = clamp(today.getFullYear(), today.getMonth());
  const thisMonthDate = new Date(today.getFullYear(), today.getMonth(), thisMonthDay);

  const target =
    thisMonthDate >= today
      ? thisMonthDate
      : (() => {
          const y = today.getFullYear();
          const m = today.getMonth() + 1;
          const day = clamp(y, m);
          return new Date(y, m, day);
        })();

  return target.toISOString().slice(0, 10);
}

/**
 * Money due out (unpaid debts + upcoming subscription renewals + upcoming
 * payroll) and money due in (unpaid invoices), merged into one sorted feed
 * for the Finance overview's "Upcoming Payments" widget.
 *
 * Window: every overdue item, regardless of age, plus anything due within
 * the next `withinDays` days (default 30) — so the widget stays useful
 * without needing its own pagination.
 */
export async function getUpcomingPayments(withinDays = 30): Promise<{
  due: UpcomingPayment[];
  toReceive: UpcomingPayment[];
}> {
  const supabase = await createClient();

  const [
    { data: invoices, error: invError },
    { data: debts, error: debtError },
    { data: subscriptions, error: subError },
    { data: employees, error: empError },
  ] = await Promise.all([
    supabase
      .from("invoices")
      .select("id, client_name, amount, status, due_date")
      .in("status", ["outstanding", "overdue"]),
    supabase
      .from("debts")
      .select("id, counterparty, principal, paid_amount, due_date, status")
      .in("status", ["outstanding", "overdue"])
      .not("due_date", "is", null),
    supabase
      .from("subscriptions")
      .select("id, vendor_name, cost, renewal_date, status")
      .eq("status", "active")
      .not("renewal_date", "is", null),
    supabase
      .from("employees")
      .select("id, full_name, salary, pay_day, status")
      .eq("status", "active")
      .not("pay_day", "is", null)
      .not("salary", "is", null),
  ]);

  if (invError) throw new Error(`Failed to load invoices: ${invError.message}`);
  if (debtError) throw new Error(`Failed to load debts: ${debtError.message}`);
  if (subError) throw new Error(`Failed to load subscriptions: ${subError.message}`);
  if (empError) throw new Error(`Failed to load employees: ${empError.message}`);

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const horizon = new Date(today);
  horizon.setDate(horizon.getDate() + withinDays);

  const inWindow = (isoDate: string) => new Date(isoDate) <= horizon; // overdue items are always < horizon too

  const toReceive: UpcomingPayment[] = (invoices ?? [])
    .filter((row) => inWindow(row.due_date))
    .map((row) => ({
      id: row.id,
      direction: "to_receive" as const,
      source: "invoice" as const,
      label: row.client_name,
      amount: Number(row.amount),
      dueDate: row.due_date,
      overdue: row.status === "overdue" || new Date(row.due_date) < today,
    }));

  const dueFromDebts: UpcomingPayment[] = (debts ?? [])
    .filter((row) => row.due_date && inWindow(row.due_date))
    .map((row) => ({
      id: row.id,
      direction: "due" as const,
      source: "debt" as const,
      label: row.counterparty,
      amount: Number(row.principal) - Number(row.paid_amount),
      dueDate: row.due_date as string,
      overdue: row.status === "overdue" || new Date(row.due_date as string) < today,
    }));

  const dueFromSubscriptions: UpcomingPayment[] = (subscriptions ?? [])
    .filter((row) => row.renewal_date && inWindow(row.renewal_date))
    .map((row) => ({
      id: row.id,
      direction: "due" as const,
      source: "subscription" as const,
      label: `${row.vendor_name} renewal`,
      amount: Number(row.cost),
      dueDate: row.renewal_date as string,
      overdue: new Date(row.renewal_date as string) < today,
    }));

  const dueFromPayroll: UpcomingPayment[] = (employees ?? [])
    .map((row) => ({
      id: row.id,
      direction: "due" as const,
      source: "employee" as const,
      label: `${row.full_name} salary`,
      amount: Number(row.salary),
      dueDate: nextPayDate(Number(row.pay_day), today),
      overdue: false, // always projected forward, so never in the past
    }))
    .filter((row) => inWindow(row.dueDate));

  const byDueDateAsc = (a: UpcomingPayment, b: UpcomingPayment) =>
    new Date(a.dueDate).getTime() - new Date(b.dueDate).getTime();

  return {
    due: [...dueFromDebts, ...dueFromSubscriptions, ...dueFromPayroll].sort(byDueDateAsc),
    toReceive: toReceive.sort(byDueDateAsc),
  };
}

// ---------------------------------------------------------------------------
// CRM — Companies, Contacts, Leads (pipeline), activity log, follow-up
// tasks. This is the second real module (after Finance) — see
// app/crm/actions.ts for the writes, and lib/data.ts for how getCrmData()
// below replaces the mock salesFunnel / open-leads / pipeline-value KPIs on
// the Executive Dashboard.
// ---------------------------------------------------------------------------

const FUNNEL_ORDER = ["new", "contacted", "qualified", "proposal", "won"] as const;
const FUNNEL_LABELS: Record<(typeof FUNNEL_ORDER)[number], string> = {
  new: "Leads",
  contacted: "Contacted",
  qualified: "Qualified",
  proposal: "Proposal",
  won: "Closed Won",
};

export async function getCrmCompanies(): Promise<CrmCompany[]> {
  const supabase = await createClient();

  const [{ data: companies, error }, { data: contacts }, { data: leads }] = await Promise.all([
    supabase
      .from("crm_companies")
      .select("id, name, industry, website, notes, created_at, profiles(full_name)")
      .order("created_at", { ascending: false }),
    supabase.from("crm_contacts").select("company_id"),
    supabase.from("crm_leads").select("company_id"),
  ]);

  if (error) throw new Error(`Failed to load companies: ${error.message}`);

  const contactCounts = new Map<string, number>();
  for (const row of contacts ?? []) {
    if (!row.company_id) continue;
    contactCounts.set(row.company_id, (contactCounts.get(row.company_id) ?? 0) + 1);
  }
  const leadCounts = new Map<string, number>();
  for (const row of leads ?? []) {
    if (!row.company_id) continue;
    leadCounts.set(row.company_id, (leadCounts.get(row.company_id) ?? 0) + 1);
  }

  return (companies ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      name: row.name,
      industry: row.industry,
      website: row.website,
      notes: row.notes,
      contactCount: contactCounts.get(row.id) ?? 0,
      leadCount: leadCounts.get(row.id) ?? 0,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

export async function getCrmContacts(): Promise<CrmContact[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("crm_contacts")
    .select(
      "id, company_id, full_name, email, phone, title, notes, created_at, profiles(full_name), crm_companies(name)"
    )
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Failed to load contacts: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const company = Array.isArray(row.crm_companies) ? row.crm_companies[0] : row.crm_companies;
    return {
      id: row.id,
      companyId: row.company_id,
      companyName: company?.name ?? null,
      fullName: row.full_name,
      email: row.email,
      phone: row.phone,
      title: row.title,
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Full pipeline, newest-updated first, joined with company/contact/owner
 * names, plus a client-side rollup of each lead's open and overdue
 * follow-up task counts (kept simple — internal tool, small tables).
 */
export async function getCrmLeads(): Promise<CrmLead[]> {
  const supabase = await createClient();

  const [{ data, error }, { data: tasks }] = await Promise.all([
    supabase
      .from("crm_leads")
      .select(
        `id, title, company_id, contact_id, stage, value, source, owner_id,
         expected_close_date, notes, converted_project_id, created_at, updated_at,
         crm_companies(name),
         crm_contacts(full_name, email),
         owner:profiles!crm_leads_owner_id_fkey(full_name),
         creator:profiles!crm_leads_created_by_fkey(full_name)`
      )
      .order("updated_at", { ascending: false }),
    supabase.from("crm_lead_tasks").select("lead_id, due_date, done").eq("done", false),
  ]);

  if (error) throw new Error(`Failed to load leads: ${error.message}`);

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const openTaskCounts = new Map<string, number>();
  const overdueTaskCounts = new Map<string, number>();
  for (const row of tasks ?? []) {
    openTaskCounts.set(row.lead_id, (openTaskCounts.get(row.lead_id) ?? 0) + 1);
    if (new Date(row.due_date) < today) {
      overdueTaskCounts.set(row.lead_id, (overdueTaskCounts.get(row.lead_id) ?? 0) + 1);
    }
  }

  return (data ?? []).map((row) => {
    const company = Array.isArray(row.crm_companies) ? row.crm_companies[0] : row.crm_companies;
    const contact = Array.isArray(row.crm_contacts) ? row.crm_contacts[0] : row.crm_contacts;
    const owner = Array.isArray(row.owner) ? row.owner[0] : row.owner;
    const creator = Array.isArray(row.creator) ? row.creator[0] : row.creator;
    return {
      id: row.id,
      title: row.title,
      companyId: row.company_id,
      companyName: company?.name ?? null,
      contactId: row.contact_id,
      contactName: contact?.full_name ?? null,
      contactEmail: contact?.email ?? null,
      stage: row.stage,
      value: Number(row.value),
      source: row.source,
      ownerId: row.owner_id,
      ownerName: owner?.full_name ?? null,
      expectedCloseDate: row.expected_close_date,
      notes: row.notes,
      convertedProjectId: row.converted_project_id,
      openTaskCount: openTaskCounts.get(row.id) ?? 0,
      overdueTaskCount: overdueTaskCounts.get(row.id) ?? 0,
      createdByName: creator?.full_name ?? null,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  });
}

export async function getCrmLead(leadId: string): Promise<CrmLead | null> {
  const leads = await getCrmLeads();
  return leads.find((l) => l.id === leadId) ?? null;
}

export async function getLeadActivities(leadId: string): Promise<CrmLeadActivity[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("crm_lead_activities")
    .select("id, lead_id, kind, content, created_at, profiles(full_name)")
    .eq("lead_id", leadId)
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Failed to load lead activity: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      leadId: row.lead_id,
      kind: row.kind,
      content: row.content,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * All open (not-done) follow-up tasks across every lead, soonest due first,
 * with an `overdue` flag. Used by both the CRM Tasks page and (optionally)
 * a dashboard widget later.
 */
export async function getOpenLeadTasks(): Promise<CrmLeadTask[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("crm_lead_tasks")
    .select("id, lead_id, title, due_date, done, created_at, profiles(full_name), crm_leads(title)")
    .eq("done", false)
    .order("due_date", { ascending: true });

  if (error) throw new Error(`Failed to load lead tasks: ${error.message}`);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const lead = Array.isArray(row.crm_leads) ? row.crm_leads[0] : row.crm_leads;
    return {
      id: row.id,
      leadId: row.lead_id,
      leadTitle: lead?.title ?? null,
      title: row.title,
      dueDate: row.due_date,
      done: row.done,
      overdue: new Date(row.due_date) < today,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Real CRM numbers for the Executive Dashboard — replaces the mock
 * open-leads / pipeline-value KPIs and the mock salesFunnel array. Funnel
 * counts are cumulative ("reached this stage or beyond"), matching the
 * shape of the original mock data (monotonically decreasing).
 */
export async function getCrmData(): Promise<{ kpis: KpiCard[]; salesFunnel: FunnelStage[] }> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("crm_leads").select("stage, value, created_at");

  if (error) throw new Error(`Failed to load CRM dashboard data: ${error.message}`);

  const rows = data ?? [];
  const openRows = rows.filter((r) => r.stage !== "won" && r.stage !== "lost");
  const openLeadsCount = openRows.length;
  const pipelineValue = openRows.reduce((sum, r) => sum + Number(r.value), 0);

  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);
  const newThisWeek = rows.filter((r) => new Date(r.created_at) >= weekAgo).length;

  const rank = (stage: string) => FUNNEL_ORDER.indexOf(stage as (typeof FUNNEL_ORDER)[number]);
  const salesFunnel: FunnelStage[] = FUNNEL_ORDER.map((stage, i) => ({
    stage: FUNNEL_LABELS[stage],
    count: rows.filter((r) => r.stage !== "lost" && rank(r.stage) >= i).length,
  }));

  const kpis: KpiCard[] = [
    {
      id: "open-leads",
      label: "Open Leads",
      value: String(openLeadsCount),
      delta: newThisWeek ? `+${newThisWeek} this week` : undefined,
      trend: newThisWeek ? "up" : "flat",
      tone: "primary",
      sourceModule: "crm",
    },
    {
      id: "pipeline-value",
      label: "Pipeline Value",
      value: (pipelineValue / 1000).toFixed(1),
      unit: "K",
      delta: `${rows.filter((r) => r.stage === "proposal").length} in final stage`,
      trend: pipelineValue > 0 ? "up" : "flat",
      tone: "success",
      sourceModule: "crm",
    },
  ];

  return { kpis, salesFunnel };
}

// ---------------------------------------------------------------------------
// Projects — minimal real table. A "won" lead auto-creates a draft row here
// (see app/crm/actions.ts:updateLeadStage), so CRM → Projects is a genuine
// handoff instead of two disconnected modules.
// ---------------------------------------------------------------------------

export async function getProjects(): Promise<Project[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("projects")
    .select(
      "id, name, client_name, company_id, status, source_lead_id, notes, created_at, profiles(full_name), crm_companies(name), crm_leads(title)"
    )
    .order("created_at", { ascending: false });

  if (error) throw new Error(`Failed to load projects: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const company = Array.isArray(row.crm_companies) ? row.crm_companies[0] : row.crm_companies;
    const lead = Array.isArray(row.crm_leads) ? row.crm_leads[0] : row.crm_leads;
    return {
      id: row.id,
      name: row.name,
      clientName: row.client_name,
      companyId: row.company_id,
      companyName: company?.name ?? null,
      status: row.status,
      sourceLeadId: row.source_lead_id,
      sourceLeadTitle: lead?.title ?? null,
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

const PROJECT_STATUS_LABELS: Record<string, ProjectStatusSlice["status"]> = {
  on_track: "On Track",
  at_risk: "At Risk",
  delayed: "Delayed",
  completed: "Completed",
};

/**
 * Project status rollup for the Executive Dashboard's Project Progress
 * chart, plus the "Active Projects" KPI (everything not completed).
 */
export async function getProjectsData(): Promise<{
  kpis: KpiCard[];
  projectStatus: ProjectStatusSlice[];
}> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("projects").select("status");

  if (error) throw new Error(`Failed to load project dashboard data: ${error.message}`);

  const rows = data ?? [];
  const counts: Record<string, number> = { on_track: 0, at_risk: 0, delayed: 0, completed: 0 };
  for (const row of rows) counts[row.status] = (counts[row.status] ?? 0) + 1;

  const projectStatus: ProjectStatusSlice[] = Object.entries(counts).map(([status, count]) => ({
    status: PROJECT_STATUS_LABELS[status],
    count,
  }));

  const activeCount = rows.filter((r) => r.status !== "completed").length;

  const kpis: KpiCard[] = [
    {
      id: "active-projects",
      label: "Active Projects",
      value: String(activeCount),
      delta: `${counts.at_risk + counts.delayed} at risk or delayed`,
      trend: "flat",
      tone: "neutral",
      sourceModule: "projects",
    },
  ];

  return { kpis, projectStatus };
}
SANESTIX_EOF

echo "3/3 -- Restoring src/lib/data.ts (merges Finance + CRM + Projects)..."
cat > "src/lib/data.ts" << 'SANESTIX_EOF'
import type { DashboardData } from "./types";
import { getFinanceData, getCrmData, getProjectsData } from "./supabase/queries";

// -----------------------------------------------------------------------
// STATUS (update this comment as modules go live):
//   Finance   → REAL, from Supabase (finance_transactions + invoices)
//   Projects  → REAL, from Supabase (projects)
//   CRM       → REAL, from Supabase (crm_leads + friends)
//
// The mock block below now only supplies the activity feed and the one
// "Overdue Tasks" KPI, since Projects doesn't have its own task table yet
// (that's the next phase — a proper Kanban with tasks/assignees/due dates).
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
  // Only "Overdue Tasks" stays mock — Projects doesn't have a tasks table yet.
  const mockOnlyKpiIds = new Set(["overdue-tasks"]);
  const mockOnlyKpis = MOCK_DASHBOARD_DATA.kpis.filter((k) => mockOnlyKpiIds.has(k.id));

  const [finance, crm, projects] = await Promise.all([
    getFinanceData(),
    getCrmData(),
    getProjectsData(),
  ]);

  return {
    ...MOCK_DASHBOARD_DATA,
    generatedAt: new Date().toISOString(),
    kpis: [...finance.kpis, ...projects.kpis, ...crm.kpis, ...mockOnlyKpis],
    revenueTrend: finance.revenueTrend.length ? finance.revenueTrend : MOCK_DASHBOARD_DATA.revenueTrend,
    cashFlow: finance.cashFlow.length ? finance.cashFlow : MOCK_DASHBOARD_DATA.cashFlow,
    salesFunnel: crm.salesFunnel.some((s) => s.count > 0) ? crm.salesFunnel : MOCK_DASHBOARD_DATA.salesFunnel,
    projectStatus: projects.projectStatus.some((s) => s.count > 0)
      ? projects.projectStatus
      : MOCK_DASHBOARD_DATA.projectStatus,
  };
}
SANESTIX_EOF

echo ""
echo "Building to verify everything compiles..."
npm run build

echo ""
echo "Done. Restart your app (pm2 restart ... / docker compose up -d --build) and check /projects and /crm both work."
