#!/usr/bin/env bash
# Sanestix Finance — Phase 4: full CRUD (delete) on every register,
# "mark salary paid" payroll history, and payment-proof photo upload.
# Run from the ROOT of your repo (same place package.json lives).
set -e

mkdir -p src/components/finance src/app/finance/vendors src/app/finance/subscriptions src/app/finance/assets src/app/finance/debts src/app/finance/invoices src/app/finance/employees supabase

echo "1 — Writing src/lib/types.ts..."
cat > src/lib/types.ts << 'SANESTIX_EOF'
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
SANESTIX_EOF

echo "2 — Writing src/lib/supabase/queries.ts..."
cat > src/lib/supabase/queries.ts << 'SANESTIX_EOF'
import { createClient } from "@/lib/supabase/server";
import { formatCurrency } from "@/lib/utils";
import type {
  Asset,
  CashFlowPoint,
  Debt,
  Employee,
  EmployeePayment,
  Founder,
  Invoice,
  KpiCard,
  LoanBalance,
  LoanEntry,
  ProfitDistribution,
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
    .select("id, occurred_on, kind, category, amount, note, profiles(full_name)")
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
    .select("id, client_name, amount, status, due_date, profiles(full_name)")
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
      "id, vendor_name, cost, billing_cycle, renewal_date, owner, status, notes, created_at, profiles(full_name)"
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
      "id, name, purchase_date, cost, owner, condition, serial_number, notes, created_at, profiles(full_name)"
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
      "id, counterparty, principal, paid_amount, due_date, status, notes, created_at, profiles(full_name)"
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
SANESTIX_EOF

echo "3 — Writing src/app/finance/actions.ts..."
cat > src/app/finance/actions.ts << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";

export async function addTransaction(formData: FormData) {
  const kind = String(formData.get("kind") ?? "");
  const category = String(formData.get("category") ?? "") || null;
  const amount = Number(formData.get("amount"));
  const occurredOn = String(formData.get("occurredOn") ?? "");
  const note = String(formData.get("note") ?? "") || null;

  if (!["revenue", "expense"].includes(kind) || !occurredOn || !(amount > 0)) {
    redirect("/finance/transactions?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("finance_transactions").insert({
    kind,
    category,
    amount,
    occurred_on: occurredOn,
    note,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/transactions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/transactions");
  revalidatePath("/finance");
  redirect("/finance/transactions");
}

export async function deleteTransaction(formData: FormData) {
  const transactionId = String(formData.get("transactionId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/finance/transactions");

  if (!transactionId) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Missing transaction id")}`);
  }

  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this transaction")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete a transaction")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Transaction was not deleted.")}`);
  }

  const { error } = await supabase.from("finance_transactions").delete().eq("id", transactionId);

  if (error) {
    redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/transactions");
  revalidatePath("/finance/income");
  revalidatePath("/finance/expenses");
  revalidatePath("/finance");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Finance module session gate — asks for the account password once before
// letting a signed-in user into /finance/*, then sets a session cookie
// (cleared on sign-out) so they aren't asked again until they log in again.
// ---------------------------------------------------------------------------

export async function verifyFinanceAccess(formData: FormData) {
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/finance");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "You must be signed in."
      )}`
    );
  }

  if (!password) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "Password is required."
      )}`
    );
  }

  const { error } = await supabase.auth.signInWithPassword({ email: user.email, password });

  if (error) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "Incorrect password."
      )}`
    );
  }

  const cookieStore = await cookies();
  cookieStore.set("finance_verified", "1", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  });

  redirect(redirectTo);
}

export async function addInvoice(formData: FormData) {
  const clientName = String(formData.get("clientName") ?? "");
  const amount = Number(formData.get("amount"));
  const status = String(formData.get("status") ?? "outstanding");
  const dueDate = String(formData.get("dueDate") ?? "");

  if (!clientName || !dueDate || !(amount > 0)) {
    redirect("/finance/invoices?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("invoices").insert({
    client_name: clientName,
    amount,
    status,
    due_date: dueDate,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect("/finance/invoices");
}

export async function updateInvoiceStatus(formData: FormData) {
  const invoiceId = String(formData.get("invoiceId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!invoiceId || !["outstanding", "paid", "overdue"].includes(status)) {
    redirect("/finance/invoices?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("invoices").update({ status }).eq("id", invoiceId);

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect("/finance/invoices");
}

export async function addLoanEntry(formData: FormData) {
  const founderId = String(formData.get("founderId") ?? "");
  const direction = String(formData.get("direction") ?? "");
  const amount = Number(formData.get("amount"));
  const occurredOn = String(formData.get("occurredOn") ?? "");
  const description = String(formData.get("description") ?? "");

  if (!founderId || !direction || !occurredOn || !description || !(amount > 0)) {
    redirect("/finance/loans?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("founder_loans").insert({
    founder_id: founderId,
    direction,
    amount,
    occurred_on: occurredOn,
    description,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/loans?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/loans");
  redirect("/finance/loans");
}

export async function addProfitDistribution(formData: FormData) {
  const periodMonth = String(formData.get("periodMonth") ?? "");
  const grossProfit = Number(formData.get("grossProfit"));
  const capitalReserve = Number(formData.get("capitalReserve") ?? 0);
  const loanRepayment = Number(formData.get("loanRepayment") ?? 0);
  const charityPct = Number(formData.get("charityPct") ?? 10);
  const note = String(formData.get("note") ?? "") || null;

  if (!periodMonth || !(grossProfit >= 0)) {
    redirect("/finance/profit-split?error=Please provide a period and a valid gross profit");
  }

  const distributable = Math.max(0, grossProfit - capitalReserve - loanRepayment);
  const charityAmount = distributable * (charityPct / 100);
  const perFounderAmount = (distributable - charityAmount) / 3;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("profit_distributions").insert({
    period_month: `${periodMonth}-01`,
    gross_profit: grossProfit,
    capital_reserve: capitalReserve,
    loan_repayment: loanRepayment,
    distributable_profit: distributable,
    charity_pct: charityPct,
    charity_amount: charityAmount,
    per_founder_amount: perFounderAmount,
    note,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/profit-split?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/profit-split");
  redirect("/finance/profit-split");
}

// ---------------------------------------------------------------------------
// Phase 2 registers — Vendors, Subscriptions, Assets, Debts, Employees
// ---------------------------------------------------------------------------

export async function addVendor(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const category = String(formData.get("category") ?? "") || null;
  const contactPerson = String(formData.get("contactPerson") ?? "") || null;
  const contactEmail = String(formData.get("contactEmail") ?? "") || null;
  const paymentTerms = String(formData.get("paymentTerms") ?? "") || null;
  const status = String(formData.get("status") ?? "active");

  if (!name || !["active", "inactive"].includes(status)) {
    redirect("/finance/vendors?error=Please fill in the vendor name");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("vendors").insert({
    name,
    category,
    contact_person: contactPerson,
    contact_email: contactEmail,
    payment_terms: paymentTerms,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/vendors");
  redirect("/finance/vendors");
}

export async function updateVendorStatus(formData: FormData) {
  const vendorId = String(formData.get("vendorId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!vendorId || !["active", "inactive"].includes(status)) {
    redirect("/finance/vendors?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("vendors").update({ status }).eq("id", vendorId);

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/vendors");
  redirect("/finance/vendors");
}

export async function addSubscription(formData: FormData) {
  const vendorName = String(formData.get("vendorName") ?? "").trim();
  const cost = Number(formData.get("cost"));
  const billingCycle = String(formData.get("billingCycle") ?? "monthly");
  const renewalDate = String(formData.get("renewalDate") ?? "") || null;
  const owner = String(formData.get("owner") ?? "") || null;
  const status = String(formData.get("status") ?? "active");

  if (!vendorName || !(cost >= 0) || !["monthly", "annual"].includes(billingCycle)) {
    redirect("/finance/subscriptions?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("subscriptions").insert({
    vendor_name: vendorName,
    cost,
    billing_cycle: billingCycle,
    renewal_date: renewalDate,
    owner,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/subscriptions");
  redirect("/finance/subscriptions");
}

export async function updateSubscriptionStatus(formData: FormData) {
  const subscriptionId = String(formData.get("subscriptionId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!subscriptionId || !["active", "cancelled"].includes(status)) {
    redirect("/finance/subscriptions?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("subscriptions")
    .update({ status })
    .eq("id", subscriptionId);

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/subscriptions");
  redirect("/finance/subscriptions");
}

export async function addAsset(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const purchaseDate = String(formData.get("purchaseDate") ?? "");
  const cost = Number(formData.get("cost"));
  const owner = String(formData.get("owner") ?? "") || null;
  const condition = String(formData.get("condition") ?? "good");
  const serialNumber = String(formData.get("serialNumber") ?? "") || null;

  if (
    !name ||
    !purchaseDate ||
    !(cost >= 0) ||
    !["new", "good", "fair", "poor", "disposed"].includes(condition)
  ) {
    redirect("/finance/assets?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("assets").insert({
    name,
    purchase_date: purchaseDate,
    cost,
    owner,
    condition,
    serial_number: serialNumber,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/assets");
  redirect("/finance/assets");
}

export async function updateAssetCondition(formData: FormData) {
  const assetId = String(formData.get("assetId") ?? "");
  const condition = String(formData.get("condition") ?? "");

  if (!assetId || !["new", "good", "fair", "poor", "disposed"].includes(condition)) {
    redirect("/finance/assets?error=Invalid condition update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("assets").update({ condition }).eq("id", assetId);

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/assets");
  redirect("/finance/assets");
}

export async function addDebt(formData: FormData) {
  const counterparty = String(formData.get("counterparty") ?? "").trim();
  const principal = Number(formData.get("principal"));
  const paidAmount = Number(formData.get("paidAmount") ?? 0);
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const status = String(formData.get("status") ?? "outstanding");

  if (!counterparty || !(principal >= 0) || !(paidAmount >= 0)) {
    redirect("/finance/debts?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("debts").insert({
    counterparty,
    principal,
    paid_amount: paidAmount,
    due_date: dueDate,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/debts");
  redirect("/finance/debts");
}

export async function updateDebtStatus(formData: FormData) {
  const debtId = String(formData.get("debtId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!debtId || !["outstanding", "paid", "overdue"].includes(status)) {
    redirect("/finance/debts?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("debts").update({ status }).eq("id", debtId);

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/debts");
  redirect("/finance/debts");
}

export async function addEmployee(formData: FormData) {
  const fullName = String(formData.get("fullName") ?? "").trim();
  const role = String(formData.get("role") ?? "") || null;
  const salaryRaw = formData.get("salary");
  const salary = salaryRaw && String(salaryRaw).trim() !== "" ? Number(salaryRaw) : null;
  const startDate = String(formData.get("startDate") ?? "") || null;
  const status = String(formData.get("status") ?? "active");
  const payDayRaw = formData.get("payDay");
  const payDay = payDayRaw && String(payDayRaw).trim() !== "" ? Number(payDayRaw) : null;

  if (
    !fullName ||
    (salary !== null && !(salary >= 0)) ||
    (payDay !== null && !(Number.isInteger(payDay) && payDay >= 1 && payDay <= 31))
  ) {
    redirect("/finance/employees?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("employees").insert({
    full_name: fullName,
    role,
    salary,
    start_date: startDate,
    status,
    pay_day: payDay,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  redirect("/finance/employees");
}

export async function updateEmployeeStatus(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!employeeId || !["active", "inactive"].includes(status)) {
    redirect("/finance/employees?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("employees").update({ status }).eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  redirect("/finance/employees");
}

// ---------------------------------------------------------------------------
// Delete support — same "re-enter your password" confirmation pattern as
// deleteTransaction, applied to every Phase 2 register.
// ---------------------------------------------------------------------------

async function confirmPasswordOrRedirect(
  password: string,
  redirectTo: string
): Promise<Awaited<ReturnType<typeof createClient>>> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete this")}`);
  }
  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Nothing was deleted.")}`);
  }

  return supabase;
}

export async function deleteVendor(formData: FormData) {
  const vendorId = String(formData.get("vendorId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/vendors";

  if (!vendorId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing vendor id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("vendors").delete().eq("id", vendorId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/vendors");
  redirect(redirectTo);
}

export async function deleteSubscription(formData: FormData) {
  const subscriptionId = String(formData.get("subscriptionId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/subscriptions";

  if (!subscriptionId)
    redirect(`${redirectTo}?error=${encodeURIComponent("Missing subscription id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("subscriptions").delete().eq("id", subscriptionId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/subscriptions");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteAsset(formData: FormData) {
  const assetId = String(formData.get("assetId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/assets";

  if (!assetId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing asset id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("assets").delete().eq("id", assetId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/assets");
  redirect(redirectTo);
}

export async function deleteDebt(formData: FormData) {
  const debtId = String(formData.get("debtId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/debts";

  if (!debtId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing debt id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("debts").delete().eq("id", debtId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/debts");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteInvoice(formData: FormData) {
  const invoiceId = String(formData.get("invoiceId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/invoices";

  if (!invoiceId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing invoice id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("invoices").delete().eq("id", invoiceId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteEmployee(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/employees";

  if (!employeeId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing employee id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("employees").delete().eq("id", employeeId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Payroll — mark a salary as paid for a given month, with an optional photo
// of the payment proof (bank transfer screenshot, receipt, etc).
// ---------------------------------------------------------------------------

export async function markSalaryPaid(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const amount = Number(formData.get("amount"));
  const payPeriodRaw = String(formData.get("payPeriod") ?? ""); // "YYYY-MM"
  const notes = String(formData.get("notes") ?? "") || null;
  const proof = formData.get("proof");

  if (!employeeId || !(amount > 0) || !/^\d{4}-\d{2}$/.test(payPeriodRaw)) {
    redirect("/finance/employees?error=Please fill in employee, amount and pay period");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  let proofUrl: string | null = null;

  if (proof instanceof File && proof.size > 0) {
    if (!proof.type.startsWith("image/")) {
      redirect("/finance/employees?error=Payment proof must be an image file");
    }
    if (proof.size > 5 * 1024 * 1024) {
      redirect("/finance/employees?error=Payment proof image must be under 5MB");
    }

    const ext = proof.name.split(".").pop()?.toLowerCase() || "jpg";
    const path = `${employeeId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("payment-proofs")
      .upload(path, proof, { contentType: proof.type, upsert: false });

    if (uploadError) {
      redirect(
        `/finance/employees?error=${encodeURIComponent(`Proof upload failed: ${uploadError.message}`)}`
      );
    }

    proofUrl = supabase.storage.from("payment-proofs").getPublicUrl(path).data.publicUrl;
  }

  const { error } = await supabase.from("employee_payments").insert({
    employee_id: employeeId,
    amount,
    pay_period: `${payPeriodRaw}-01`,
    proof_url: proofUrl,
    notes,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect("/finance/employees");
}

export async function deleteEmployeePayment(formData: FormData) {
  const paymentId = String(formData.get("paymentId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/employees";

  if (!paymentId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing payment id")}`);

  const supabase = await confirmPasswordOrRedirect(password, redirectTo);
  const { error } = await supabase.from("employee_payments").delete().eq("id", paymentId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function updateEmployeePayDay(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const payDayRaw = String(formData.get("payDay") ?? "").trim();
  const payDay = payDayRaw === "" ? null : Number(payDayRaw);

  if (!employeeId) {
    redirect("/finance/employees?error=Invalid payday update");
  }
  if (payDay !== null && !(Number.isInteger(payDay) && payDay >= 1 && payDay <= 31)) {
    redirect("/finance/employees?error=Payday must be a day of month between 1 and 31");
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("employees")
    .update({ pay_day: payDay })
    .eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect("/finance/employees");
}
SANESTIX_EOF

echo "4 — Writing src/components/finance/register-delete-button.tsx..."
cat > src/components/finance/register-delete-button.tsx << 'SANESTIX_EOF'
"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";

export function RegisterDeleteButton({
  action,
  idFieldName,
  idValue,
  redirectTo,
  label = "item",
}: {
  action: (formData: FormData) => void;
  idFieldName: string;
  idValue: string;
  redirectTo: string;
  label?: string;
}) {
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        type="button"
        onClick={() => setConfirming(true)}
        aria-label={`Delete ${label}`}
        title={`Delete ${label}`}
        className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-error-tint hover:text-error"
      >
        <Trash2 size={14} />
      </button>
    );
  }

  return (
    <form action={action} className="flex items-center justify-end gap-1.5">
      <input type="hidden" name={idFieldName} value={idValue} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <input
        type="password"
        name="password"
        required
        autoFocus
        placeholder="Password"
        className="w-28 border border-error/40 bg-background px-2 py-1 font-mono-data text-[11px] text-on-surface focus:border-error focus:outline-none"
      />
      <button
        type="submit"
        className="bg-error px-2 py-1.5 text-[10px] font-mono-data uppercase tracking-wider text-white transition hover:brightness-110"
      >
        Confirm
      </button>
      <button
        type="button"
        onClick={() => setConfirming(false)}
        aria-label="Cancel delete"
        title="Cancel"
        className="inline-flex items-center justify-center rounded-[2px] p-1 text-on-surface-variant transition hover:text-on-surface"
      >
        <X size={14} />
      </button>
    </form>
  );
}
SANESTIX_EOF

echo "5 — Writing src/components/finance/mark-salary-paid-form.tsx..."
cat > src/components/finance/mark-salary-paid-form.tsx << 'SANESTIX_EOF'
"use client";

import type { Employee } from "@/lib/types";

export function MarkSalaryPaidForm({
  employees,
  action,
}: {
  employees: Employee[];
  action: (formData: FormData) => void;
}) {
  const currentPeriod = new Date().toISOString().slice(0, 7); // "YYYY-MM"

  return (
    <form action={action} className="mt-4 space-y-3" encType="multipart/form-data">
      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Employee
        </label>
        <select
          name="employeeId"
          required
          defaultValue=""
          onChange={(e) => {
            const opt = e.currentTarget.selectedOptions[0];
            const salary = opt?.dataset.salary;
            const form = e.currentTarget.form;
            const amountInput = form?.elements.namedItem("amount") as HTMLInputElement | null;
            if (amountInput && salary && !amountInput.value) {
              amountInput.value = salary;
            }
          }}
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
        >
          <option value="" disabled>
            Select employee
          </option>
          {employees.map((e) => (
            <option key={e.id} value={e.id} data-salary={e.salary ?? ""}>
              {e.fullName}
              {e.salary !== null ? ` — ${e.salary.toLocaleString()} PKR` : ""}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Amount paid (PKR)
        </label>
        <input
          type="number"
          name="amount"
          step="1"
          min="1"
          required
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
          placeholder="0"
        />
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Pay period (month)
        </label>
        <input
          type="month"
          name="payPeriod"
          required
          defaultValue={currentPeriod}
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
        />
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Payment proof (photo)
        </label>
        <input
          type="file"
          name="proof"
          accept="image/*"
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] file:mr-3 file:border-0 file:bg-surface-container-high file:px-3 file:py-1.5 file:font-mono-data file:text-[11px] file:uppercase file:tracking-wider focus:border-primary focus:outline-none"
        />
        <p className="mt-1 text-[11px] text-on-surface-variant/70">
          Optional — screenshot or photo of the bank transfer/receipt. Max 5MB.
        </p>
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Notes
        </label>
        <input
          type="text"
          name="notes"
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
          placeholder="Optional"
        />
      </div>

      <button
        type="submit"
        className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
      >
        Mark salary paid
      </button>
    </form>
  );
}
SANESTIX_EOF

echo "6 — Writing src/app/finance/vendors/page.tsx..."
cat > src/app/finance/vendors/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getVendors } from "@/lib/supabase/queries";
import { addVendor, updateVendorStatus, deleteVendor } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

const CATEGORY_SUGGESTIONS = [
  "software",
  "hosting",
  "legal",
  "marketing",
  "equipment",
  "professional services",
];

export default async function VendorsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const vendors = await getVendors();
  const activeCount = vendors.filter((v) => v.status === "active").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Vendors"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Vendors</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Recurring suppliers and service providers, with contact and payment terms.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total vendors
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{vendors.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">{activeCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Inactive
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {vendors.length - activeCount}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a vendor</CardTitle>
          <CardDescription>Register a new supplier or service provider.</CardDescription>

          <form action={addVendor} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Name
              </label>
              <input
                type="text"
                name="name"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Hostinger"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Category
              </label>
              <input
                type="text"
                name="category"
                list="vendor-category-suggestions"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. hosting"
              />
              <datalist id="vendor-category-suggestions">
                {CATEGORY_SUGGESTIONS.map((c) => (
                  <option key={c} value={c} />
                ))}
              </datalist>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact person
              </label>
              <input
                type="text"
                name="contactPerson"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact email
              </label>
              <input
                type="email"
                name="contactEmail"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Payment terms
              </label>
              <input
                type="text"
                name="paymentTerms"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Net 15"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="active"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add vendor
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Vendor Register</CardTitle>
          <CardDescription>All vendors, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Category</th>
                  <th className="pb-2 pr-4">Contact</th>
                  <th className="pb-2 pr-4">Terms</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {vendors.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No vendors recorded yet.
                    </td>
                  </tr>
                )}
                {vendors.map((v) => (
                  <tr key={v.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{v.name}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{v.category ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {v.contactPerson ?? v.contactEmail ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {v.paymentTerms ?? "—"}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="vendorId"
                        idValue={v.id}
                        status={v.status}
                        tone={v.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "inactive", label: "Inactive" },
                        ]}
                        action={updateVendorStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteVendor}
                          idFieldName="vendorId"
                          idValue={v.id}
                          redirectTo="/finance/vendors"
                          label="vendor"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "7 — Writing src/app/finance/subscriptions/page.tsx..."
cat > src/app/finance/subscriptions/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { formatCurrency } from "@/lib/utils";
import { getSubscriptions } from "@/lib/supabase/queries";
import { addSubscription, updateSubscriptionStatus, deleteSubscription } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function SubscriptionsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const subscriptions = await getSubscriptions();
  const active = subscriptions.filter((s) => s.status === "active");

  const monthlyBurn = active.reduce(
    (sum, s) => sum + (s.billingCycle === "monthly" ? s.cost : s.cost / 12),
    0
  );

  const today = new Date().toISOString().slice(0, 10);
  const in30Days = new Date();
  in30Days.setDate(in30Days.getDate() + 30);
  const upcomingRenewals = active.filter(
    (s) => s.renewalDate && s.renewalDate >= today && s.renewalDate <= in30Days.toISOString().slice(0, 10)
  ).length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Subscriptions"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Subscriptions</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Central register for monthly and annual tools — renewals, owners, and costs.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active subscriptions
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{active.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Estimated monthly burn
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(monthlyBurn)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Renewing in 30 days
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {upcomingRenewals}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a subscription</CardTitle>
          <CardDescription>Register a new recurring tool or service.</CardDescription>

          <form action={addSubscription} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Vendor / tool name
              </label>
              <input
                type="text"
                name="vendorName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. SEMrush"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Cost (PKR)
              </label>
              <input
                type="number"
                name="cost"
                step="1"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Billing cycle
              </label>
              <select
                name="billingCycle"
                defaultValue="monthly"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="monthly">Monthly</option>
                <option value="annual">Annual</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Renewal date
              </label>
              <input
                type="date"
                name="renewalDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Owner
              </label>
              <input
                type="text"
                name="owner"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who manages this"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add subscription
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Subscription Register</CardTitle>
          <CardDescription>Soonest renewal first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Vendor</th>
                  <th className="pb-2 pr-4">Cycle</th>
                  <th className="pb-2 pr-4">Renews</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4 text-right">Cost</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {subscriptions.length === 0 && (
                  <tr>
                    <td colSpan={7} className="py-6 text-center text-on-surface-variant">
                      No subscriptions recorded yet.
                    </td>
                  </tr>
                )}
                {subscriptions.map((s) => (
                  <tr key={s.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{s.vendorName}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant capitalize">
                      {s.billingCycle}
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {s.renewalDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{s.owner ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(s.cost)}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="subscriptionId"
                        idValue={s.id}
                        status={s.status}
                        tone={s.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "cancelled", label: "Cancelled" },
                        ]}
                        action={updateSubscriptionStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteSubscription}
                          idFieldName="subscriptionId"
                          idValue={s.id}
                          redirectTo="/finance/subscriptions"
                          label="subscription"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "8 — Writing src/app/finance/assets/page.tsx..."
cat > src/app/finance/assets/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { formatCurrency } from "@/lib/utils";
import { getAssets } from "@/lib/supabase/queries";
import { addAsset, updateAssetCondition, deleteAsset } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

const today = () => new Date().toISOString().slice(0, 10);

export default async function AssetsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const assets = await getAssets();
  const totalValue = assets
    .filter((a) => a.condition !== "disposed")
    .reduce((sum, a) => sum + a.cost, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Assets"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Assets</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Company-owned equipment and high-value purchases, tracked separately from expenses.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total assets
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{assets.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Book value (active)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(totalValue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Disposed
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {assets.filter((a) => a.condition === "disposed").length}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add an asset</CardTitle>
          <CardDescription>Register new equipment or a high-value purchase.</CardDescription>

          <form action={addAsset} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Name
              </label>
              <input
                type="text"
                name="name"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Microphone"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Purchase date
              </label>
              <input
                type="date"
                name="purchaseDate"
                required
                defaultValue={today()}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Cost (PKR)
              </label>
              <input
                type="number"
                name="cost"
                step="1"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Owner
              </label>
              <input
                type="text"
                name="owner"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who holds this asset"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Serial number
              </label>
              <input
                type="text"
                name="serialNumber"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Condition
              </label>
              <select
                name="condition"
                defaultValue="good"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="new">New</option>
                <option value="good">Good</option>
                <option value="fair">Fair</option>
                <option value="poor">Poor</option>
                <option value="disposed">Disposed</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add asset
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Asset Register</CardTitle>
          <CardDescription>Newest purchases first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Purchased</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4">Serial</th>
                  <th className="pb-2 pr-4 text-right">Cost</th>
                  <th className="pb-2 pr-4">Condition</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {assets.length === 0 && (
                  <tr>
                    <td colSpan={7} className="py-6 text-center text-on-surface-variant">
                      No assets recorded yet.
                    </td>
                  </tr>
                )}
                {assets.map((a) => (
                  <tr key={a.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{a.name}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {a.purchaseDate}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{a.owner ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {a.serialNumber ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(a.cost)}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="assetId"
                        idValue={a.id}
                        status={a.condition}
                        tone={
                          a.condition === "disposed"
                            ? "neutral"
                            : a.condition === "poor"
                              ? "error"
                              : a.condition === "fair"
                                ? "warning"
                                : "success"
                        }
                        options={[
                          { value: "new", label: "New" },
                          { value: "good", label: "Good" },
                          { value: "fair", label: "Fair" },
                          { value: "poor", label: "Poor" },
                          { value: "disposed", label: "Disposed" },
                        ]}
                        action={updateAssetCondition}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteAsset}
                          idFieldName="assetId"
                          idValue={a.id}
                          redirectTo="/finance/assets"
                          label="asset"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "9 — Writing src/app/finance/debts/page.tsx..."
cat > src/app/finance/debts/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { formatCurrency } from "@/lib/utils";
import { getDebts } from "@/lib/supabase/queries";
import { addDebt, updateDebtStatus, deleteDebt } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function DebtsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const debts = await getDebts();
  const totalOutstanding = debts
    .filter((d) => d.status !== "paid")
    .reduce((sum, d) => sum + d.remainingBalance, 0);
  const overdueCount = debts.filter((d) => d.status === "overdue").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Debts & Liabilities"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
          Debts & Liabilities
        </h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Non-founder liabilities — vendor payables, taxes, credit cards, and external loans.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total liabilities
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{debts.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Outstanding balance
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {formatCurrency(totalOutstanding)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueCount}</p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a liability</CardTitle>
          <CardDescription>Record a new debt or payable.</CardDescription>

          <form action={addDebt} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Counterparty
              </label>
              <input
                type="text"
                name="counterparty"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who is owed"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Principal (PKR)
              </label>
              <input
                type="number"
                name="principal"
                step="1"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Paid so far (PKR)
              </label>
              <input
                type="number"
                name="paidAmount"
                step="1"
                min="0"
                defaultValue={0}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="outstanding"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="outstanding">Outstanding</option>
                <option value="paid">Paid</option>
                <option value="overdue">Overdue</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add liability
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Debt & Liability Register</CardTitle>
          <CardDescription>Soonest due date first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Counterparty</th>
                  <th className="pb-2 pr-4">Due</th>
                  <th className="pb-2 pr-4 text-right">Principal</th>
                  <th className="pb-2 pr-4 text-right">Paid</th>
                  <th className="pb-2 pr-4 text-right">Remaining</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {debts.length === 0 && (
                  <tr>
                    <td colSpan={7} className="py-6 text-center text-on-surface-variant">
                      No liabilities recorded yet.
                    </td>
                  </tr>
                )}
                {debts.map((d) => (
                  <tr key={d.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{d.counterparty}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {d.dueDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(d.principal)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-success">
                      {formatCurrency(d.paidAmount)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-error">
                      {formatCurrency(d.remainingBalance)}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="debtId"
                        idValue={d.id}
                        status={d.status}
                        tone={
                          d.status === "paid"
                            ? "success"
                            : d.status === "overdue"
                              ? "error"
                              : "warning"
                        }
                        options={[
                          { value: "outstanding", label: "Outstanding" },
                          { value: "paid", label: "Paid" },
                          { value: "overdue", label: "Overdue" },
                        ]}
                        action={updateDebtStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteDebt}
                          idFieldName="debtId"
                          idValue={d.id}
                          redirectTo="/finance/debts"
                          label="liability"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "10 — Writing src/app/finance/invoices/page.tsx..."
cat > src/app/finance/invoices/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils";
import { getInvoices } from "@/lib/supabase/queries";
import { addInvoice, updateInvoiceStatus, deleteInvoice } from "@/app/finance/actions";
import { InvoiceStatusForm } from "@/components/finance/invoice-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";

export const dynamic = "force-dynamic";

export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const invoices = await getInvoices();

  const today = new Date().toISOString().slice(0, 10);
  const outstandingTotal = invoices
    .filter((i) => i.status === "outstanding")
    .reduce((sum, i) => sum + i.amount, 0);
  const overdueTotal = invoices
    .filter((i) => i.status === "overdue")
    .reduce((sum, i) => sum + i.amount, 0);
  const paidTotal = invoices
    .filter((i) => i.status === "paid")
    .reduce((sum, i) => sum + i.amount, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Invoices"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Invoices</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client invoices behind the Outstanding Invoices KPI, in PKR.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Outstanding
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(outstandingTotal)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {formatCurrency(overdueTotal)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Paid (all time)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(paidTotal)}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>New invoice</CardTitle>
          <CardDescription>Bill a client and track it through to payment.</CardDescription>

          <form action={addInvoice} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Client name
              </label>
              <input
                type="text"
                name="clientName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Systems Ltd"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Amount (PKR)
              </label>
              <input
                type="number"
                name="amount"
                step="1"
                min="1"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="outstanding"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="outstanding">Outstanding</option>
                <option value="paid">Paid</option>
                <option value="overdue">Overdue</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                required
                defaultValue={today}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Create invoice
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>All invoices</CardTitle>
          <CardDescription>Sorted by due date. Update status inline.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Client</th>
                  <th className="pb-2 pr-4">Due date</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 pr-4">Logged by</th>
                  <th className="pb-2 pr-4 text-right">Amount</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {invoices.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No invoices yet.
                    </td>
                  </tr>
                )}
                {invoices.map((inv) => (
                  <tr key={inv.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{inv.clientName}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {inv.dueDate}
                    </td>
                    <td className="py-2.5 pr-4">
                      <InvoiceStatusForm
                        invoiceId={inv.id}
                        status={inv.status}
                        action={updateInvoiceStatus}
                      />
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {inv.createdByName ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-on-surface">
                      {formatCurrency(inv.amount)}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteInvoice}
                          idFieldName="invoiceId"
                          idValue={inv.id}
                          redirectTo="/finance/invoices"
                          label="invoice"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "11 — Writing src/app/finance/employees/page.tsx..."
cat > src/app/finance/employees/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { EmployeePayDayForm } from "@/components/finance/employee-payday-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { MarkSalaryPaidForm } from "@/components/finance/mark-salary-paid-form";
import { formatCurrency } from "@/lib/utils";
import { getEmployees, getEmployeePayments } from "@/lib/supabase/queries";
import {
  addEmployee,
  updateEmployeeStatus,
  updateEmployeePayDay,
  deleteEmployee,
  markSalaryPaid,
  deleteEmployeePayment,
} from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function EmployeesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [employees, payments] = await Promise.all([getEmployees(), getEmployeePayments()]);
  const active = employees.filter((e) => e.status === "active");
  const monthlyPayroll = active.reduce((sum, e) => sum + (e.salary ?? 0), 0);

  const lastPaidByEmployee = new Map<string, (typeof payments)[number]>();
  for (const payment of payments) {
    if (!lastPaidByEmployee.has(payment.employeeId)) {
      lastPaidByEmployee.set(payment.employeeId, payment);
    }
  }

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Employees"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Employees</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Payroll and compensation register — salary, role, and status per person.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active employees
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{active.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Monthly payroll
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(monthlyPayroll)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Inactive
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {employees.length - active.length}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add an employee</CardTitle>
          <CardDescription>Register a new team member.</CardDescription>

          <form action={addEmployee} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Full name
              </label>
              <input
                type="text"
                name="fullName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Ayesha Khan"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Role
              </label>
              <input
                type="text"
                name="role"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Video Editor"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Salary (PKR / month)
              </label>
              <input
                type="number"
                name="salary"
                step="1"
                min="0"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Start date
              </label>
              <input
                type="date"
                name="startDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Payday (day of month)
              </label>
              <input
                type="number"
                name="payDay"
                min="1"
                max="31"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. 1 — optional, powers Upcoming Payments"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="active"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add employee
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Employee Register</CardTitle>
          <CardDescription>Newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Role</th>
                  <th className="pb-2 pr-4">Start date</th>
                  <th className="pb-2 pr-4 text-right">Salary</th>
                  <th className="pb-2 pr-4">Payday</th>
                  <th className="pb-2 pr-4">Last paid</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {employees.length === 0 && (
                  <tr>
                    <td colSpan={8} className="py-6 text-center text-on-surface-variant">
                      No employees recorded yet.
                    </td>
                  </tr>
                )}
                {employees.map((e) => (
                  <tr key={e.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{e.fullName}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{e.role ?? "—"}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {e.startDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {e.salary !== null ? formatCurrency(e.salary) : "—"}
                    </td>
                    <td className="py-2.5 pr-4">
                      <EmployeePayDayForm
                        employeeId={e.id}
                        payDay={e.payDay}
                        action={updateEmployeePayDay}
                      />
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {lastPaidByEmployee.has(e.id) ? (
                        <>
                          {lastPaidByEmployee.get(e.id)!.paidOn}
                          {lastPaidByEmployee.get(e.id)!.proofUrl && (
                            <a
                              href={lastPaidByEmployee.get(e.id)!.proofUrl!}
                              target="_blank"
                              rel="noreferrer"
                              className="ml-1.5 text-primary underline underline-offset-2"
                            >
                              proof
                            </a>
                          )}
                        </>
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="py-2.5 pr-4">
                      <RegisterStatusForm
                        idFieldName="employeeId"
                        idValue={e.id}
                        status={e.status}
                        tone={e.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "inactive", label: "Inactive" },
                        ]}
                        action={updateEmployeeStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteEmployee}
                          idFieldName="employeeId"
                          idValue={e.id}
                          redirectTo="/finance/employees"
                          label="employee"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Log a salary payment</CardTitle>
          <CardDescription>
            Mark a payday as paid, optionally attaching a photo of the transfer proof.
          </CardDescription>
          <MarkSalaryPaidForm employees={active} action={markSalaryPaid} />
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Payment History</CardTitle>
          <CardDescription>Every logged salary payment, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Employee</th>
                  <th className="pb-2 pr-4">Pay period</th>
                  <th className="pb-2 pr-4">Paid on</th>
                  <th className="pb-2 pr-4 text-right">Amount</th>
                  <th className="pb-2 pr-4">Proof</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {payments.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No salary payments logged yet.
                    </td>
                  </tr>
                )}
                {payments.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{p.employeeName ?? "—"}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {p.payPeriod.slice(0, 7)}
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {p.paidOn}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-success">
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="py-2.5 pr-4">
                      {p.proofUrl ? (
                        <a
                          href={p.proofUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-block"
                        >
                          <img
                            src={p.proofUrl}
                            alt={`Payment proof for ${p.employeeName ?? "employee"}`}
                            className="h-9 w-9 rounded-[2px] border border-outline-variant object-cover"
                          />
                        </a>
                      ) : (
                        <span className="text-on-surface-variant/70">—</span>
                      )}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteEmployeePayment}
                          idFieldName="paymentId"
                          idValue={p.id}
                          redirectTo="/finance/employees"
                          label="payment"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "12 — Writing supabase/schema-phase4-crud-and-payroll.sql..."
cat > supabase/schema-phase4-crud-and-payroll.sql << 'SANESTIX_EOF'
-- Sanestix OS — Phase 4: full CRUD (delete) on every register + payroll
-- payment history with photo proof-of-payment.
-- Run this in the Supabase SQL editor AFTER schema.sql, schema-phase2 and
-- schema-phase3. Safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Delete policies — vendors, subscriptions, assets, debts, employees,
--    invoices previously only supported insert/update. This unlocks the
--    "Delete" button added to each register page.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['vendors', 'subscriptions', 'assets', 'debts', 'employees']
  loop
    execute format(
      'drop policy if exists "Authenticated users can delete %1$s" on public.%1$s;
       create policy "Authenticated users can delete %1$s" on public.%1$s
         for delete to authenticated using (true);', t
    );
  end loop;
end $$;

drop policy if exists "Authenticated users can delete invoices" on public.invoices;
create policy "Authenticated users can delete invoices"
  on public.invoices for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 2. employee_payments — one row per payday marked "paid", with an optional
--    photo of the transfer/receipt as proof.
-- ---------------------------------------------------------------------------
create table if not exists public.employee_payments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  amount numeric(12, 2) not null check (amount >= 0),
  pay_period date not null, -- first day of the month this payment covers
  paid_on date not null default current_date,
  proof_url text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.employee_payments enable row level security;

drop policy if exists "Authenticated users can read employee_payments" on public.employee_payments;
create policy "Authenticated users can read employee_payments"
  on public.employee_payments for select to authenticated using (true);

drop policy if exists "Authenticated users can write employee_payments" on public.employee_payments;
create policy "Authenticated users can write employee_payments"
  on public.employee_payments for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update employee_payments" on public.employee_payments;
create policy "Authenticated users can update employee_payments"
  on public.employee_payments for update to authenticated using (true);

drop policy if exists "Authenticated users can delete employee_payments" on public.employee_payments;
create policy "Authenticated users can delete employee_payments"
  on public.employee_payments for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 3. Storage bucket for payment proof photos. Public read (the app is
--    already gated behind the finance password), authenticated-only write.
--    Object paths are namespaced by employee id + a random suffix, so a
--    stranger with the URL would have to already know/guess it.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', true)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload payment proofs" on storage.objects;
create policy "Authenticated users can upload payment proofs"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-proofs');

drop policy if exists "Anyone can view payment proofs" on storage.objects;
create policy "Anyone can view payment proofs"
  on storage.objects for select to public
  using (bucket_id = 'payment-proofs');

drop policy if exists "Authenticated users can delete payment proofs" on storage.objects;
create policy "Authenticated users can delete payment proofs"
  on storage.objects for delete to authenticated
  using (bucket_id = 'payment-proofs');
SANESTIX_EOF

echo "Done writing files. Building..."
npm run build
