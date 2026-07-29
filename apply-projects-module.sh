#!/usr/bin/env bash
# Sanestix OS -- Projects module (full build)
# Adds: projects + tasks tables, a real Projects registry page, a project
# detail page with a drag-and-drop Kanban board (@dnd-kit), task comments,
# multi-assignee tasks, project team management, and live dashboard KPIs.
#
# Run from the ROOT of your repo (same place you ran apply-finance-fixes.sh).
#
# IMPORTANT: also run supabase/schema-phase5-projects.sql in your Supabase
# SQL editor (Project -> SQL Editor) -- this script writes the file but
# can't run SQL against your database for you.
set -e

mkdir -p supabase src/app/projects "src/app/projects/[id]" src/components/projects src/lib/supabase

echo "1/13 -- New database tables (projects, tasks, members, comments) — run the matching SQL in Supabase too..."
cat > "supabase/schema-phase5-projects.sql" << 'SANESTIX_EOF'
-- Sanestix OS — Phase 5 schema: Projects module
-- Run this once in the Supabase SQL editor, AFTER schema.sql and
-- schema-phase2-registers.sql. Safe to re-run: everything is
-- IF NOT EXISTS / CREATE OR REPLACE.
--
-- Tables:
--   projects        — one row per client project
--   project_members — who's on a project (many-to-many: profiles <-> projects)
--   tasks           — Kanban tasks, always scoped to a project
--   task_assignees  — who's assigned to a task (many-to-many: profiles <-> tasks)
--   task_comments   — discussion thread on a task
--
-- Also (re-)creates activity_log and notifications if they don't already
-- exist, since this repo's earlier phases assumed those tables were added
-- ad hoc — see src/lib/audit.ts. Safe no-ops if they're already there.

-- ---------------------------------------------------------------------------
-- 0. activity_log + notifications (idempotent safety net — see src/lib/audit.ts)
-- ---------------------------------------------------------------------------
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  actor_email text,
  action text not null,
  entity text not null,
  entity_id uuid,
  summary text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id),
  type text not null,
  title text not null,
  body text,
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.activity_log enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Authenticated users can read activity_log" on public.activity_log;
create policy "Authenticated users can read activity_log"
  on public.activity_log for select to authenticated using (true);

drop policy if exists "Authenticated users can write activity_log" on public.activity_log;
create policy "Authenticated users can write activity_log"
  on public.activity_log for insert to authenticated with check (true);

drop policy if exists "Authenticated users can read notifications" on public.notifications;
create policy "Authenticated users can read notifications"
  on public.notifications for select to authenticated using (true);

drop policy if exists "Authenticated users can write notifications" on public.notifications;
create policy "Authenticated users can write notifications"
  on public.notifications for insert to authenticated with check (true);

-- ---------------------------------------------------------------------------
-- 1. Projects
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_name text,
  description text,
  status text not null default 'on_track'
    check (status in ('on_track', 'at_risk', 'delayed', 'completed')),
  owner_id uuid references public.profiles (id),
  start_date date,
  end_date date,
  budget numeric(12, 2),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'contributor',
  added_at timestamptz not null default now(),
  unique (project_id, member_id)
);

-- ---------------------------------------------------------------------------
-- 2. Tasks (Kanban)
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'backlog'
    check (status in ('backlog', 'todo', 'in_progress', 'review', 'done')),
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high', 'urgent')),
  due_date date,
  position bigint not null default 0,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_assignees (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  unique (task_id, member_id)
);

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  author_id uuid references public.profiles (id),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists tasks_project_id_idx on public.tasks (project_id);
create index if not exists tasks_status_idx on public.tasks (status);
create index if not exists task_comments_task_id_idx on public.task_comments (task_id);

-- ---------------------------------------------------------------------------
-- 3. RLS — internal team tool: any signed-in user can read/write everything.
--    Tighten later (e.g. restrict deletes to owner/admin) once you have
--    real staff roles.
-- ---------------------------------------------------------------------------
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.task_comments enable row level security;

drop policy if exists "Authenticated users can read projects" on public.projects;
create policy "Authenticated users can read projects"
  on public.projects for select to authenticated using (true);
drop policy if exists "Authenticated users can write projects" on public.projects;
create policy "Authenticated users can write projects"
  on public.projects for insert to authenticated with check (true);
drop policy if exists "Authenticated users can update projects" on public.projects;
create policy "Authenticated users can update projects"
  on public.projects for update to authenticated using (true);
drop policy if exists "Authenticated users can delete projects" on public.projects;
create policy "Authenticated users can delete projects"
  on public.projects for delete to authenticated using (true);

drop policy if exists "Authenticated users can read project_members" on public.project_members;
create policy "Authenticated users can read project_members"
  on public.project_members for select to authenticated using (true);
drop policy if exists "Authenticated users can write project_members" on public.project_members;
create policy "Authenticated users can write project_members"
  on public.project_members for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete project_members" on public.project_members;
create policy "Authenticated users can delete project_members"
  on public.project_members for delete to authenticated using (true);

drop policy if exists "Authenticated users can read tasks" on public.tasks;
create policy "Authenticated users can read tasks"
  on public.tasks for select to authenticated using (true);
drop policy if exists "Authenticated users can write tasks" on public.tasks;
create policy "Authenticated users can write tasks"
  on public.tasks for insert to authenticated with check (true);
drop policy if exists "Authenticated users can update tasks" on public.tasks;
create policy "Authenticated users can update tasks"
  on public.tasks for update to authenticated using (true);
drop policy if exists "Authenticated users can delete tasks" on public.tasks;
create policy "Authenticated users can delete tasks"
  on public.tasks for delete to authenticated using (true);

drop policy if exists "Authenticated users can read task_assignees" on public.task_assignees;
create policy "Authenticated users can read task_assignees"
  on public.task_assignees for select to authenticated using (true);
drop policy if exists "Authenticated users can write task_assignees" on public.task_assignees;
create policy "Authenticated users can write task_assignees"
  on public.task_assignees for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete task_assignees" on public.task_assignees;
create policy "Authenticated users can delete task_assignees"
  on public.task_assignees for delete to authenticated using (true);

drop policy if exists "Authenticated users can read task_comments" on public.task_comments;
create policy "Authenticated users can read task_comments"
  on public.task_comments for select to authenticated using (true);
drop policy if exists "Authenticated users can write task_comments" on public.task_comments;
create policy "Authenticated users can write task_comments"
  on public.task_comments for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete task_comments" on public.task_comments;
create policy "Authenticated users can delete task_comments"
  on public.task_comments for delete to authenticated using (true);
SANESTIX_EOF

echo "2/13 -- Overwriting lib/types.ts (adds Projects module types)..."
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
// Phase 5 — Projects module (real, Supabase-backed)
// ---------------------------------------------------------------------------

export type ProjectRecordStatus = "on_track" | "at_risk" | "delayed" | "completed";

export interface ProjectPerson {
  id: string;
  fullName: string | null;
}

export interface ProjectListItem {
  id: string;
  name: string;
  clientName: string | null;
  description: string | null;
  status: ProjectRecordStatus;
  ownerId: string | null;
  ownerName: string | null;
  startDate: string | null;
  endDate: string | null;
  budget: number | null;
  taskCount: number;
  doneTaskCount: number;
  overdueTaskCount: number;
  createdAt: string;
}

export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type TaskPriority = "low" | "medium" | "high" | "urgent";

export interface TaskComment {
  id: string;
  taskId: string;
  authorName: string | null;
  body: string;
  createdAt: string;
}

export interface ProjectTask {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  position: number;
  assignees: ProjectPerson[];
  comments: TaskComment[];
  createdByName: string | null;
  createdAt: string;
}
SANESTIX_EOF

echo "3/13 -- Overwriting lib/supabase/queries.ts (adds Projects queries)..."
cat > "src/lib/supabase/queries.ts" << 'SANESTIX_EOF'
import { createClient } from "@/lib/supabase/server";
import { formatCurrency, formatRelativeDate } from "@/lib/utils";
import type {
  ActivityItem,
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
  ProjectListItem,
  ProjectPerson,
  ProjectStatusSlice,
  ProjectTask,
  RevenuePoint,
  Subscription,
  TaskComment,
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
// Phase 5 — Projects module
// ---------------------------------------------------------------------------

const PROJECT_STATUS_LABEL: Record<string, ProjectStatusSlice["status"]> = {
  on_track: "On Track",
  at_risk: "At Risk",
  delayed: "Delayed",
  completed: "Completed",
};

/**
 * Full project list, newest first, with the owner's name and a live task
 * count / done count / overdue count rolled up from `tasks`.
 */
export async function getProjects(): Promise<ProjectListItem[]> {
  const supabase = await createClient();

  const [{ data: projects, error: projError }, { data: tasks, error: taskError }] =
    await Promise.all([
      supabase
        .from("projects")
        .select(
          "id, name, client_name, description, status, owner_id, start_date, end_date, budget, created_at, profiles!projects_owner_id_fkey(full_name)"
        )
        .order("created_at", { ascending: false }),
      supabase.from("tasks").select("id, project_id, status, due_date"),
    ]);

  if (projError) throw new Error(`Failed to load projects: ${projError.message}`);
  if (taskError) throw new Error(`Failed to load tasks: ${taskError.message}`);

  const todayIso = new Date().toISOString().slice(0, 10);

  return (projects ?? []).map((row) => {
    const owner = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    const projectTasks = (tasks ?? []).filter((t) => t.project_id === row.id);
    const doneTaskCount = projectTasks.filter((t) => t.status === "done").length;
    const overdueTaskCount = projectTasks.filter(
      (t) => t.status !== "done" && t.due_date && t.due_date < todayIso
    ).length;

    return {
      id: row.id,
      name: row.name,
      clientName: row.client_name,
      description: row.description,
      status: row.status,
      ownerId: row.owner_id,
      ownerName: owner?.full_name ?? null,
      startDate: row.start_date,
      endDate: row.end_date,
      budget: row.budget !== null ? Number(row.budget) : null,
      taskCount: projectTasks.length,
      doneTaskCount,
      overdueTaskCount,
      createdAt: row.created_at,
    };
  });
}

/**
 * One project by id, or null if it doesn't exist / isn't visible under RLS.
 */
export async function getProjectById(projectId: string): Promise<ProjectListItem | null> {
  const projects = await getProjects();
  return projects.find((p) => p.id === projectId) ?? null;
}

/**
 * Everyone assigned to a project (project_members), joined with their name.
 */
export async function getProjectMembers(projectId: string): Promise<ProjectPerson[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("project_members")
    .select("member_id, profiles!project_members_member_id_fkey(id, full_name)")
    .eq("project_id", projectId);

  if (error) throw new Error(`Failed to load project_members: ${error.message}`);

  return (data ?? []).map((row) => {
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return { id: profile?.id ?? row.member_id, fullName: profile?.full_name ?? null };
  });
}

/**
 * Every task on a project, ordered for the Kanban board, each with its
 * assignees and full comment thread already attached (this is a small
 * internal tool — one round trip per project is plenty).
 */
export async function getProjectTasks(projectId: string): Promise<ProjectTask[]> {
  const supabase = await createClient();

  const { data: taskRows, error } = await supabase
    .from("tasks")
    .select(
      "id, project_id, title, description, status, priority, due_date, position, created_at, profiles!tasks_created_by_fkey(full_name), task_assignees(member_id, profiles!task_assignees_member_id_fkey(id, full_name))"
    )
    .eq("project_id", projectId)
    .order("position", { ascending: true });

  if (error) throw new Error(`Failed to load tasks: ${error.message}`);

  const taskIds = (taskRows ?? []).map((t) => t.id);

  const { data: commentRows, error: commentError } = taskIds.length
    ? await supabase
        .from("task_comments")
        .select("id, task_id, body, created_at, profiles!task_comments_author_id_fkey(full_name)")
        .in("task_id", taskIds)
        .order("created_at", { ascending: true })
    : { data: [], error: null };

  if (commentError) throw new Error(`Failed to load task_comments: ${commentError.message}`);

  return (taskRows ?? []).map((row) => {
    const creator = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;

    const assignees: ProjectPerson[] = (row.task_assignees ?? []).map((a) => {
      const profile = Array.isArray(a.profiles) ? a.profiles[0] : a.profiles;
      return { id: profile?.id ?? a.member_id, fullName: profile?.full_name ?? null };
    });

    const comments: TaskComment[] = (commentRows ?? [])
      .filter((c) => c.task_id === row.id)
      .map((c) => {
        const author = Array.isArray(c.profiles) ? c.profiles[0] : c.profiles;
        return {
          id: c.id,
          taskId: c.task_id,
          authorName: author?.full_name ?? null,
          body: c.body,
          createdAt: c.created_at,
        };
      });

    return {
      id: row.id,
      projectId: row.project_id,
      title: row.title,
      description: row.description,
      status: row.status,
      priority: row.priority,
      dueDate: row.due_date,
      position: Number(row.position),
      assignees,
      comments,
      createdByName: creator?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * The next N overdue tasks across all projects, shaped as dashboard
 * activity items.
 */
export async function getOverdueTaskActivity(limit = 4): Promise<ActivityItem[]> {
  const supabase = await createClient();
  const todayIso = new Date().toISOString().slice(0, 10);

  const { data, error } = await supabase
    .from("tasks")
    .select("id, title, due_date, projects!tasks_project_id_fkey(name)")
    .neq("status", "done")
    .not("due_date", "is", null)
    .lt("due_date", todayIso)
    .order("due_date", { ascending: true })
    .limit(limit);

  if (error) throw new Error(`Failed to load overdue tasks: ${error.message}`);

  return (data ?? []).map((row) => {
    const project = Array.isArray(row.projects) ? row.projects[0] : row.projects;
    return {
      id: `task-overdue-${row.id}`,
      kind: "task_overdue",
      title: `Task overdue — ${row.title}`,
      detail: project?.name ? `Project: ${project.name}` : "Project unknown",
      timestamp: row.due_date ? formatRelativeDate(row.due_date).label : "",
      module: "projects",
    };
  });
}

/**
 * Real Projects data for the Executive Dashboard: KPI cards, the
 * On Track/At Risk/Delayed/Completed split, and recent projects/tasks
 * activity. Mirrors the shape getFinanceData() returns.
 */
export async function getProjectsDashboardData(): Promise<{
  kpis: KpiCard[];
  projectStatus: ProjectStatusSlice[];
  activity: ActivityItem[];
}> {
  const [projects, overdueTaskActivity] = await Promise.all([
    getProjects(),
    getOverdueTaskActivity(4),
  ]);

  const activeProjects = projects.filter((p) => p.status !== "completed");
  const overdueTaskCount = projects.reduce((sum, p) => sum + p.overdueTaskCount, 0);

  const counts: Record<ProjectStatusSlice["status"], number> = {
    "On Track": 0,
    "At Risk": 0,
    Delayed: 0,
    Completed: 0,
  };
  for (const p of projects) counts[PROJECT_STATUS_LABEL[p.status]] += 1;

  const projectStatus: ProjectStatusSlice[] = (
    Object.keys(counts) as ProjectStatusSlice["status"][]
  )
    .map((status) => ({ status, count: counts[status] }))
    .filter((slice) => slice.count > 0);

  const kpis: KpiCard[] = [
    {
      id: "active-projects",
      label: "Active Projects",
      value: String(activeProjects.length),
      delta: `${projects.length} total`,
      trend: "flat",
      tone: "neutral",
      sourceModule: "projects",
    },
    {
      id: "overdue-tasks",
      label: "Overdue Tasks",
      value: String(overdueTaskCount),
      delta: overdueTaskCount > 0 ? "Needs attention" : "All clear",
      trend: overdueTaskCount > 0 ? "up" : "flat",
      tone: overdueTaskCount > 0 ? "error" : "success",
      sourceModule: "projects",
    },
  ];

  const delayedActivity: ActivityItem[] = projects
    .filter((p) => p.status === "delayed")
    .slice(0, 3)
    .map((p) => ({
      id: `project-delay-${p.id}`,
      kind: "project_delay",
      title: `Project delayed — ${p.name}`,
      detail: p.clientName ? `Client: ${p.clientName}` : "No client set",
      timestamp: new Date(p.createdAt).toLocaleDateString("en-PK", {
        day: "2-digit",
        month: "short",
      }),
      module: "projects",
    }));

  return {
    kpis,
    projectStatus,
    activity: [...overdueTaskActivity, ...delayedActivity],
  };
}
SANESTIX_EOF

echo "4/13 -- Overwriting lib/data.ts (wires real Projects data into the dashboard)..."
cat > "src/lib/data.ts" << 'SANESTIX_EOF'
import type { DashboardData } from "./types";
import { getFinanceData, getProjectsDashboardData } from "./supabase/queries";

// -----------------------------------------------------------------------
// STATUS (update this comment as modules go live):
//   Finance   → REAL, from Supabase (finance_transactions + invoices)
//   Projects  → REAL, from Supabase (projects + tasks)
//   CRM       → mock, still hardcoded below
//
// When CRM gets its own tables, add a getCrmData() next to getFinanceData()
// in lib/supabase/queries.ts and merge it below the same way Finance and
// Projects are merged now. No component outside this file needs to
// change — they all consume DashboardData.
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
  const mockHandledIds = new Set([
    "revenue-mtd",
    "outstanding-invoices",
    "active-projects",
    "overdue-tasks",
  ]);
  const remainingMockKpis = MOCK_DASHBOARD_DATA.kpis.filter((k) => !mockHandledIds.has(k.id));
  const mockNonProjectActivity = MOCK_DASHBOARD_DATA.activity.filter((a) => a.module !== "projects");

  const [finance, projects] = await Promise.all([getFinanceData(), getProjectsDashboardData()]);

  return {
    ...MOCK_DASHBOARD_DATA,
    generatedAt: new Date().toISOString(),
    kpis: [...finance.kpis, ...projects.kpis, ...remainingMockKpis],
    revenueTrend: finance.revenueTrend.length ? finance.revenueTrend : MOCK_DASHBOARD_DATA.revenueTrend,
    cashFlow: finance.cashFlow.length ? finance.cashFlow : MOCK_DASHBOARD_DATA.cashFlow,
    projectStatus: projects.projectStatus.length
      ? projects.projectStatus
      : MOCK_DASHBOARD_DATA.projectStatus,
    activity: [...projects.activity, ...mockNonProjectActivity].slice(0, 6),
  };
}
SANESTIX_EOF

echo "5/13 -- New file: Projects server actions (CRUD for projects/tasks/members/comments)..."
cat > "src/app/projects/actions.ts" << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { recordActivity } from "@/lib/audit";
import type { TaskStatus } from "@/lib/types";

const PROJECT_STATUSES = ["on_track", "at_risk", "delayed", "completed"];
const TASK_STATUSES: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];
const TASK_PRIORITIES = ["low", "medium", "high", "urgent"];

// ---------------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------------

export async function addProject(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const clientName = String(formData.get("clientName") ?? "") || null;
  const description = String(formData.get("description") ?? "") || null;
  const status = String(formData.get("status") ?? "on_track");
  const ownerId = String(formData.get("ownerId") ?? "") || null;
  const startDate = String(formData.get("startDate") ?? "") || null;
  const endDate = String(formData.get("endDate") ?? "") || null;
  const budgetRaw = String(formData.get("budget") ?? "");
  const budget = budgetRaw ? Number(budgetRaw) : null;

  if (!name || !PROJECT_STATUSES.includes(status)) {
    redirect("/projects?error=Please fill in the project name");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("projects")
    .insert({
      name,
      client_name: clientName,
      description,
      status,
      owner_id: ownerId,
      start_date: startDate,
      end_date: endDate,
      budget,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/projects?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "projects",
    entityId: inserted?.id ?? null,
    summary: `Project "${name}" created`,
    notify: true,
    notifyLink: `/projects/${inserted?.id}`,
  });

  revalidatePath("/projects");
  revalidatePath("/");
  redirect("/projects");
}

export async function updateProjectStatus(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!projectId || !PROJECT_STATUSES.includes(status)) {
    redirect("/projects?error=Invalid status update");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();

  const { error } = await supabase.from("projects").update({ status }).eq("id", projectId);

  if (error) {
    redirect(`/projects?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" marked ${status.replace("_", " ")}`,
    notifyLink: "/projects",
  });

  revalidatePath("/projects");
  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/");
  redirect("/projects");
}

export async function deleteProject(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/projects";

  if (!projectId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing project id")}`);
  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this project")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete a project")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Nothing was deleted.")}`);
  }

  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();

  // Tasks, task_assignees, task_comments and project_members all cascade
  // via their foreign keys (see supabase/schema-phase5-projects.sql).
  const { error } = await supabase.from("projects").delete().eq("id", projectId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" deleted`,
    notify: true,
    notifyLink: "/projects",
  });

  revalidatePath("/projects");
  revalidatePath("/");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Project members
// ---------------------------------------------------------------------------

export async function addProjectMember(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const memberId = String(formData.get("memberId") ?? "");

  if (!projectId || !memberId) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Choose someone to add")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("project_members")
    .insert({ project_id: projectId, member_id: memberId });

  // Unique-constraint violation just means they're already a member — not
  // worth surfacing as an error.
  if (error && error.code !== "23505") {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  if (!error) {
    await recordActivity({
      supabase,
      actorId: user?.id ?? null,
      actorEmail: user?.email ?? null,
      action: "update",
      entity: "project_members",
      entityId: projectId,
      summary: "Team member added to project",
      notifyLink: `/projects/${projectId}`,
    });
  }

  revalidatePath(`/projects/${projectId}`);
  redirect(`/projects/${projectId}`);
}

export async function removeProjectMember(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const memberId = String(formData.get("memberId") ?? "");

  if (!projectId || !memberId) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Missing member")}`);
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("project_members")
    .delete()
    .eq("project_id", projectId)
    .eq("member_id", memberId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/projects/${projectId}`);
  redirect(`/projects/${projectId}`);
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

export async function addTask(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "") || null;
  const priority = String(formData.get("priority") ?? "medium");
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const assigneeIds = formData.getAll("assigneeIds").map(String).filter(Boolean);

  if (!projectId || !title || !TASK_PRIORITIES.includes(priority)) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Please fill in a task title")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("tasks")
    .insert({
      project_id: projectId,
      title,
      description,
      priority,
      due_date: dueDate,
      status: "backlog",
      position: Date.now(),
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  if (assigneeIds.length && inserted?.id) {
    await supabase
      .from("task_assignees")
      .insert(assigneeIds.map((memberId) => ({ task_id: inserted.id, member_id: memberId })));
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "tasks",
    entityId: inserted?.id ?? null,
    summary: `Task "${title}" added`,
    notifyLink: `/projects/${projectId}`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
  redirect(`/projects/${projectId}`);
}

/**
 * Called directly from the Kanban board's drag-and-drop handler (not a
 * <form> submit) — moves a task to a new column and persists the resulting
 * column order. No redirect: the client already updated optimistically,
 * this just needs the data to be correct on the next refresh.
 */
export async function moveTask(
  taskId: string,
  projectId: string,
  newStatus: TaskStatus,
  destinationOrderedIds: string[]
) {
  if (!TASK_STATUSES.includes(newStatus)) return;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error: statusError } = await supabase
    .from("tasks")
    .update({ status: newStatus, updated_at: new Date().toISOString() })
    .eq("id", taskId);

  if (statusError) {
    console.error("moveTask: failed to update status:", statusError.message);
    return;
  }

  await Promise.all(
    destinationOrderedIds.map((id, index) =>
      supabase.from("tasks").update({ position: index }).eq("id", id)
    )
  );

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "tasks",
    entityId: taskId,
    summary: `Task moved to ${newStatus.replace("_", " ")}`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
  revalidatePath("/");
}

export async function updateTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");
  const priority = String(formData.get("priority") ?? "medium");
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const assigneeIds = formData.getAll("assigneeIds").map(String).filter(Boolean);

  if (!taskId || !TASK_PRIORITIES.includes(priority)) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Invalid task update")}`);
  }

  const supabase = await createClient();

  const { error } = await supabase
    .from("tasks")
    .update({ priority, due_date: dueDate, updated_at: new Date().toISOString() })
    .eq("id", taskId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  // Simplest correct way to sync a many-to-many list from a checkbox form:
  // clear it and reinsert what's checked now.
  await supabase.from("task_assignees").delete().eq("task_id", taskId);
  if (assigneeIds.length) {
    await supabase
      .from("task_assignees")
      .insert(assigneeIds.map((memberId) => ({ task_id: taskId, member_id: memberId })));
  }

  revalidatePath(`/projects/${projectId}`);
}

export async function deleteTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");

  if (!taskId) redirect(`/projects/${projectId}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("tasks")
    .select("title")
    .eq("id", taskId)
    .maybeSingle();

  const { error } = await supabase.from("tasks").delete().eq("id", taskId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "delete",
    entity: "tasks",
    entityId: taskId,
    summary: `Task "${existing?.title ?? taskId}" deleted`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
}

export async function addTaskComment(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");
  const body = String(formData.get("body") ?? "").trim();

  if (!taskId || !body) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Comment can't be empty")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("task_comments")
    .insert({ task_id: taskId, author_id: user?.id ?? null, body });

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/projects/${projectId}`);
}
SANESTIX_EOF

echo "6/13 -- Overwriting the Projects list page (was the placeholder)..."
cat > "src/app/projects/page.tsx" << 'SANESTIX_EOF'
import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getProjects, getFounders } from "@/lib/supabase/queries";
import { addProject, updateProjectStatus, deleteProject } from "@/app/projects/actions";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STATUS_OPTIONS = [
  { value: "on_track", label: "On Track" },
  { value: "at_risk", label: "At Risk" },
  { value: "delayed", label: "Delayed" },
  { value: "completed", label: "Completed" },
];

const STATUS_TONE: Record<string, "success" | "warning" | "error" | "neutral"> = {
  on_track: "success",
  at_risk: "warning",
  delayed: "error",
  completed: "neutral",
};

export default async function ProjectsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [projects, people] = await Promise.all([getProjects(), getFounders()]);

  const activeCount = projects.filter((p) => p.status !== "completed").length;
  const overdueCount = projects.reduce((sum, p) => sum + p.overdueTaskCount, 0);
  const atRiskCount = projects.filter((p) => p.status === "at_risk" || p.status === "delayed")
    .length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Projects"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Projects</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client delivery workspace — projects, tasks, and ownership, live from Supabase.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total projects
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{projects.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-primary">{activeCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            At risk / delayed
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">{atRiskCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue tasks
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueCount}</p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>New project</CardTitle>
          <CardDescription>Kick off a new piece of client work.</CardDescription>

          <form action={addProject} className="mt-4 space-y-3">
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
                placeholder="e.g. Atlas Migration"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Client
              </label>
              <input
                type="text"
                name="clientName"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Owner
              </label>
              <select
                name="ownerId"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">Unassigned</option>
                {people.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.fullName ?? "Unnamed"}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
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
                  End date
                </label>
                <input
                  type="date"
                  name="endDate"
                  className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Budget (PKR)
              </label>
              <input
                type="number"
                name="budget"
                min="0"
                step="0.01"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Description
              </label>
              <textarea
                name="description"
                rows={2}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="on_track"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                {STATUS_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Create project
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Project Registry</CardTitle>
          <CardDescription>All projects, newest first.</CardDescription>

          <div className="mt-4 max-h-[640px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Client</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4">Tasks</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No projects yet — create the first one on the left.
                    </td>
                  </tr>
                )}
                {projects.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50 align-top">
                    <td className="py-2.5 pr-4">
                      <Link href={`/projects/${p.id}`} className="text-on-surface hover:text-primary">
                        {p.name}
                      </Link>
                      {p.budget !== null && (
                        <p className="mt-0.5 font-mono-data text-[11px] text-on-surface-variant">
                          {formatCurrency(p.budget)}
                        </p>
                      )}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{p.clientName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{p.ownerName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.doneTaskCount}/{p.taskCount} done
                      {p.overdueTaskCount > 0 && (
                        <span className="ml-2">
                          <StatusPill tone="error">{p.overdueTaskCount} overdue</StatusPill>
                        </span>
                      )}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="projectId"
                        idValue={p.id}
                        status={STATUS_OPTIONS.find((o) => o.value === p.status)?.label ?? p.status}
                        tone={STATUS_TONE[p.status]}
                        options={STATUS_OPTIONS}
                        action={updateProjectStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteProject}
                          idFieldName="projectId"
                          idValue={p.id}
                          redirectTo="/projects"
                          label="project"
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

echo "7/13 -- New file: Project detail page (Kanban + team)..."
cat > "src/app/projects/[id]/page.tsx" << 'SANESTIX_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { MemberPicker } from "@/components/projects/member-picker";
import { TaskBoard } from "@/components/projects/task-board";
import {
  getProjectById,
  getProjectMembers,
  getProjectTasks,
  getFounders,
} from "@/lib/supabase/queries";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STATUS_LABEL: Record<string, string> = {
  on_track: "On Track",
  at_risk: "At Risk",
  delayed: "Delayed",
  completed: "Completed",
};

const STATUS_TONE: Record<string, "success" | "warning" | "error" | "neutral"> = {
  on_track: "success",
  at_risk: "warning",
  delayed: "error",
  completed: "neutral",
};

export default async function ProjectDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const project = await getProjectById(id);
  if (!project) notFound();

  const [members, tasks, everyone] = await Promise.all([
    getProjectMembers(id),
    getProjectTasks(id),
    getFounders(),
  ]);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Projects", project.name]}>
      <div>
        <Link
          href="/projects"
          className="inline-flex items-center gap-1.5 font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
        >
          <ArrowLeft size={13} />
          All projects
        </Link>

        <div className="mt-2 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-[28px] font-bold tracking-tight text-on-surface">{project.name}</h1>
            <p className="mt-1 text-[13px] text-on-surface-variant">
              {project.clientName ? `Client: ${project.clientName}` : "No client set"}
              {project.ownerName ? ` · Owner: ${project.ownerName}` : ""}
            </p>
          </div>
          <StatusPill tone={STATUS_TONE[project.status]}>
            {STATUS_LABEL[project.status] ?? project.status}
          </StatusPill>
        </div>

        {project.description && (
          <p className="mt-3 max-w-2xl text-[13px] leading-6 text-on-surface-variant">
            {project.description}
          </p>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Tasks
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">
            {project.doneTaskCount}/{project.taskCount}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {project.overdueTaskCount}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Budget
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">
            {project.budget !== null ? formatCurrency(project.budget) : "—"}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Timeline
          </p>
          <p className="mt-2 font-mono-data text-[12px] text-on-surface">
            {project.startDate ?? "—"} → {project.endDate ?? "—"}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <div className="lg:col-span-3">
          <Card className="p-6">
            <CardTitle>Kanban</CardTitle>
            <CardDescription>Drag a card between columns to update its status.</CardDescription>
            <div className="mt-4">
              <TaskBoard projectId={id} initialTasks={tasks} members={members} />
            </div>
          </Card>
        </div>
        <div className="lg:col-span-1">
          <MemberPicker projectId={id} members={members} everyone={everyone} />
        </div>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "8/13 -- New file: Projects loading skeleton..."
cat > "src/app/projects/loading.tsx" << 'SANESTIX_EOF'
export default function ProjectsLoading() {
  return (
    <div className="animate-pulse space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="h-7 w-56 rounded-[2px] bg-surface-container-high" />
      <div className="h-4 w-80 rounded-[2px] bg-surface-container-high" />
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-24 rounded-[2px] border border-outline-variant bg-surface" />
        ))}
      </div>
      <div className="h-72 rounded-[2px] border border-outline-variant bg-surface" />
    </div>
  );
}
SANESTIX_EOF

echo "9/13 -- New file: Projects error boundary..."
cat > "src/app/projects/error.tsx" << 'SANESTIX_EOF'
"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { RefreshCw, AlertTriangle, ArrowLeft } from "lucide-react";

export default function ProjectsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Projects module error:", error);
  }, [error]);

  const hint = useMemo(() => {
    const message = error.message ?? "";

    if (/relation .* does not exist/i.test(message) || /does not exist/i.test(message)) {
      return "This table hasn't been created in Supabase yet. Run supabase/schema-phase5-projects.sql in the Supabase SQL editor, then reload.";
    }

    if (/permission denied|row-level security|rls/i.test(message)) {
      return "Row Level Security is blocking this query. Confirm you're signed in and that the table's RLS policies grant access to the authenticated role.";
    }

    if (/fetch failed|network|ENOTFOUND|ECONNREFUSED/i.test(message)) {
      return "Couldn't reach Supabase. Check NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY in .env and that the Supabase project is active.";
    }

    return "Check the Supabase logs (Project → Logs → API) for the underlying query error.";
  }, [error.message]);

  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="w-full max-w-lg border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-error">
          <AlertTriangle size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">This projects page couldn&apos;t load</h1>
        </div>

        <p className="mt-3 font-mono-data text-[12px] text-on-surface-variant break-words">
          {error.message || "Unknown error"}
        </p>

        <div className="mt-4 border-l-2 border-warning/60 bg-warning-tint px-3 py-2">
          <p className="text-[12px] text-on-surface-variant">{hint}</p>
        </div>

        <div className="mt-5 flex flex-wrap gap-3">
          <button
            onClick={reset}
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <RefreshCw size={14} />
            Try again
          </button>
          <Link
            href="/projects"
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <ArrowLeft size={14} />
            Back to Projects
          </Link>
        </div>
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "10/13 -- New file: drag-and-drop Kanban board..."
cat > "src/components/projects/task-board.tsx" << 'SANESTIX_EOF'
"use client";

import { useState } from "react";
import {
  DndContext,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import { Plus } from "lucide-react";
import { cn, formatRelativeDate } from "@/lib/utils";
import { StatusPill } from "@/components/ui/status-pill";
import { moveTask } from "@/app/projects/actions";
import { AddTaskForm } from "@/components/projects/add-task-form";
import { TaskDetailModal } from "@/components/projects/task-detail-modal";
import type { ProjectPerson, ProjectTask, TaskStatus } from "@/lib/types";

const COLUMNS: { id: TaskStatus; label: string }[] = [
  { id: "backlog", label: "Backlog" },
  { id: "todo", label: "To Do" },
  { id: "in_progress", label: "In Progress" },
  { id: "review", label: "Review" },
  { id: "done", label: "Done" },
];

const PRIORITY_TONE: Record<string, "neutral" | "primary" | "warning" | "error"> = {
  low: "neutral",
  medium: "primary",
  high: "warning",
  urgent: "error",
};

function initials(name: string | null) {
  if (!name) return "?";
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function TaskCard({ task, onOpen }: { task: ProjectTask; onOpen: (task: ProjectTask) => void }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: task.id,
  });

  const style = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` }
    : undefined;

  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      onClick={() => onOpen(task)}
      role="button"
      tabIndex={0}
      className={cn(
        "cursor-grab select-none border border-outline-variant bg-surface p-3 text-left transition active:cursor-grabbing",
        isDragging ? "z-50 opacity-70 shadow-lg" : "hover:border-primary/40"
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-[13px] font-medium leading-snug text-on-surface">{task.title}</p>
        <StatusPill tone={PRIORITY_TONE[task.priority]} className="shrink-0">
          {task.priority}
        </StatusPill>
      </div>

      {task.dueDate && (
        <p
          className={cn(
            "mt-2 font-mono-data text-[10px] uppercase tracking-wider",
            overdue ? "text-error" : "text-on-surface-variant"
          )}
        >
          {formatRelativeDate(task.dueDate).label}
        </p>
      )}

      <div className="mt-2 flex items-center justify-between">
        <div className="flex flex-wrap gap-1">
          {task.assignees.map((a) => (
            <span
              key={a.id}
              title={a.fullName ?? "Unnamed"}
              className="flex h-5 w-5 items-center justify-center border border-outline-variant bg-background font-mono-data text-[9px] text-on-surface-variant"
            >
              {initials(a.fullName)}
            </span>
          ))}
        </div>
        {task.comments.length > 0 && (
          <span className="font-mono-data text-[10px] text-on-surface-variant/60">
            {task.comments.length} comment{task.comments.length === 1 ? "" : "s"}
          </span>
        )}
      </div>
    </div>
  );
}

function Column({
  id,
  label,
  tasks,
  onOpen,
}: {
  id: TaskStatus;
  label: string;
  tasks: ProjectTask[];
  onOpen: (task: ProjectTask) => void;
}) {
  const { setNodeRef, isOver } = useDroppable({ id });

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex w-[260px] shrink-0 flex-col border border-outline-variant bg-background",
        isOver && "border-primary/60 bg-primary/[0.03]"
      )}
    >
      <div className="flex items-center justify-between border-b border-outline-variant px-3 py-2">
        <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          {label}
        </span>
        <span className="font-mono-data text-[10px] text-on-surface-variant/60">
          {tasks.length}
        </span>
      </div>
      <div className="min-h-[140px] flex-1 space-y-2 overflow-y-auto p-2">
        {tasks.map((task) => (
          <TaskCard key={task.id} task={task} onOpen={onOpen} />
        ))}
        {tasks.length === 0 && (
          <p className="p-3 text-center text-[11px] text-on-surface-variant/50">No tasks</p>
        )}
      </div>
    </div>
  );
}

export function TaskBoard({
  projectId,
  initialTasks,
  members,
}: {
  projectId: string;
  initialTasks: ProjectTask[];
  members: ProjectPerson[];
}) {
  const [tasks, setTasks] = useState(initialTasks);
  const [activeTask, setActiveTask] = useState<ProjectTask | null>(null);
  const [addingTask, setAddingTask] = useState(false);

  // Server actions revalidate the page instead of redirecting (so the
  // board and any open task panel can update in place). When a fresh
  // `initialTasks` comes down from the server, sync local state from it —
  // computed during render (not in an effect) per React's guidance on
  // adjusting state from changed props.
  const [syncedTasks, setSyncedTasks] = useState(initialTasks);
  if (initialTasks !== syncedTasks) {
    setSyncedTasks(initialTasks);
    setTasks(initialTasks);
    setActiveTask((prev) => (prev ? initialTasks.find((t) => t.id === prev.id) ?? null : null));
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } })
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;

    const taskId = String(active.id);
    const newStatus = over.id as TaskStatus;
    const task = tasks.find((t) => t.id === taskId);
    if (!task || task.status === newStatus) return;

    const updated = tasks.map((t) => (t.id === taskId ? { ...t, status: newStatus } : t));
    setTasks(updated);

    const destinationIds = updated.filter((t) => t.status === newStatus).map((t) => t.id);
    void moveTask(taskId, projectId, newStatus, destinationIds);
  }

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Drag a card to change its status
        </p>
        <button
          onClick={() => setAddingTask(true)}
          className="flex items-center gap-1.5 bg-primary px-3 py-1.5 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
        >
          <Plus size={13} />
          Add task
        </button>
      </div>

      <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
        <div className="flex gap-3 overflow-x-auto pb-2">
          {COLUMNS.map((col) => (
            <Column
              key={col.id}
              id={col.id}
              label={col.label}
              tasks={tasks.filter((t) => t.status === col.id)}
              onOpen={setActiveTask}
            />
          ))}
        </div>
      </DndContext>

      {activeTask && (
        <TaskDetailModal
          task={activeTask}
          projectId={projectId}
          members={members}
          onClose={() => setActiveTask(null)}
        />
      )}

      {addingTask && (
        <AddTaskForm projectId={projectId} members={members} onClose={() => setAddingTask(false)} />
      )}
    </div>
  );
}
SANESTIX_EOF

echo "11/13 -- New file: add-task modal..."
cat > "src/components/projects/add-task-form.tsx" << 'SANESTIX_EOF'
"use client";

import { X } from "lucide-react";
import { addTask } from "@/app/projects/actions";
import type { ProjectPerson } from "@/lib/types";

export function AddTaskForm({
  projectId,
  members,
  onClose,
}: {
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-md overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <h2 className="text-[16px] font-semibold text-on-surface">New task</h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        <form action={addTask} className="mt-4 space-y-3">
          <input type="hidden" name="projectId" value={projectId} />

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Title
            </label>
            <input
              type="text"
              name="title"
              required
              autoFocus
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="e.g. Wire up payment webhook"
            />
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Description
            </label>
            <textarea
              name="description"
              rows={3}
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="Optional"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue="medium"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
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
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input type="checkbox" name="assigneeIds" value={m.id} />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">
                  Add project members first to assign tasks.
                </p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Add task
          </button>
        </form>
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "12/13 -- New file: task detail/edit/comments modal..."
cat > "src/components/projects/task-detail-modal.tsx" << 'SANESTIX_EOF'
"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";
import { updateTask, deleteTask, addTaskComment } from "@/app/projects/actions";
import { formatRelativeDate } from "@/lib/utils";
import type { ProjectPerson, ProjectTask } from "@/lib/types";

function formatWhen(iso: string) {
  return new Date(iso).toLocaleString("en-PK", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function TaskDetailModal({
  task,
  projectId,
  members,
  onClose,
}: {
  task: ProjectTask;
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-lg overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-[16px] font-semibold text-on-surface">{task.title}</h2>
            <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              {task.status.replace("_", " ")}
              {task.dueDate && (
                <span className={overdue ? "ml-2 text-error" : "ml-2"}>
                  · {formatRelativeDate(task.dueDate).label}
                </span>
              )}
            </p>
          </div>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        {task.description && (
          <p className="mt-3 text-[13px] leading-6 text-on-surface-variant">{task.description}</p>
        )}

        <form action={updateTask} className="mt-4 space-y-3 border-t border-outline-variant pt-4">
          <input type="hidden" name="taskId" value={task.id} />
          <input type="hidden" name="projectId" value={projectId} />

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue={task.priority}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                defaultValue={task.dueDate ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input
                    type="checkbox"
                    name="assigneeIds"
                    value={m.id}
                    defaultChecked={task.assignees.some((a) => a.id === m.id)}
                  />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">No project members yet.</p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Save changes
          </button>
        </form>

        <div className="mt-5 border-t border-outline-variant pt-4">
          <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
            Comments
          </p>
          <div className="mt-2 max-h-40 space-y-2 overflow-y-auto">
            {task.comments.length === 0 && (
              <p className="text-[12px] text-on-surface-variant/60">No comments yet.</p>
            )}
            {task.comments.map((c) => (
              <div key={c.id} className="border-l-2 border-outline-variant pl-2">
                <div className="flex items-baseline gap-2">
                  <span className="text-[12px] font-semibold text-on-surface">
                    {c.authorName ?? "Someone"}
                  </span>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/60">
                    {formatWhen(c.createdAt)}
                  </span>
                </div>
                <p className="text-[12px] text-on-surface-variant">{c.body}</p>
              </div>
            ))}
          </div>

          <form action={addTaskComment} className="mt-3 flex gap-2">
            <input type="hidden" name="taskId" value={task.id} />
            <input type="hidden" name="projectId" value={projectId} />
            <input
              name="body"
              required
              placeholder="Add a comment…"
              className="flex-1 border border-outline-variant bg-background px-2 py-1.5 text-[12px] focus:border-primary focus:outline-none"
            />
            <button
              type="submit"
              className="bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
            >
              Post
            </button>
          </form>
        </div>

        <div className="mt-5 border-t border-outline-variant pt-4">
          {!confirmingDelete ? (
            <button
              onClick={() => setConfirmingDelete(true)}
              className="flex items-center gap-2 font-mono-data text-[11px] uppercase tracking-wider text-error hover:underline"
            >
              <Trash2 size={13} />
              Delete task
            </button>
          ) : (
            <form action={deleteTask} className="flex items-center gap-2">
              <input type="hidden" name="taskId" value={task.id} />
              <input type="hidden" name="projectId" value={projectId} />
              <span className="text-[11px] text-error">Delete this task permanently?</span>
              <button
                type="submit"
                className="bg-error px-2 py-1 font-mono-data text-[10px] uppercase tracking-wider text-white transition hover:brightness-110"
              >
                Confirm
              </button>
              <button
                type="button"
                onClick={() => setConfirmingDelete(false)}
                className="text-[10px] text-on-surface-variant hover:text-on-surface"
              >
                Cancel
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "13/13 -- New file: project team panel..."
cat > "src/components/projects/member-picker.tsx" << 'SANESTIX_EOF'
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { addProjectMember, removeProjectMember } from "@/app/projects/actions";
import type { ProjectPerson } from "@/lib/types";

export function MemberPicker({
  projectId,
  members,
  everyone,
}: {
  projectId: string;
  members: ProjectPerson[];
  everyone: ProjectPerson[];
}) {
  const memberIds = new Set(members.map((m) => m.id));
  const available = everyone.filter((p) => !memberIds.has(p.id));

  return (
    <Card className="p-6">
      <CardTitle>Team</CardTitle>
      <CardDescription>Who&apos;s assigned to this project.</CardDescription>

      <div className="mt-4 space-y-2">
        {members.length === 0 && (
          <p className="text-[12px] text-on-surface-variant/60">No one added yet.</p>
        )}
        {members.map((m) => (
          <div
            key={m.id}
            className="flex items-center justify-between border border-outline-variant bg-background px-3 py-2"
          >
            <span className="text-[12px] text-on-surface">{m.fullName ?? "Unnamed"}</span>
            <form action={removeProjectMember}>
              <input type="hidden" name="projectId" value={projectId} />
              <input type="hidden" name="memberId" value={m.id} />
              <button
                type="submit"
                className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant hover:text-error"
              >
                Remove
              </button>
            </form>
          </div>
        ))}
      </div>

      {available.length > 0 && (
        <form action={addProjectMember} className="mt-4 flex gap-2 border-t border-outline-variant pt-4">
          <input type="hidden" name="projectId" value={projectId} />
          <select
            name="memberId"
            required
            className="flex-1 border border-outline-variant bg-background px-2 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
          >
            <option value="">Add a teammate…</option>
            {available.map((p) => (
              <option key={p.id} value={p.id}>
                {p.fullName ?? "Unnamed"}
              </option>
            ))}
          </select>
          <button
            type="submit"
            className="bg-primary px-3 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
          >
            Add
          </button>
        </form>
      )}
    </Card>
  );
}
SANESTIX_EOF

echo "Installing @dnd-kit/core (drag-and-drop for the Kanban board)..."
npm install @dnd-kit/core --no-audit --no-fund

echo "Building to verify everything compiles..."
npm run build

echo ""
echo "Done. Next steps:"
echo "  1. Open the Supabase SQL editor and run supabase/schema-phase5-projects.sql"
echo "     (safe to re-run -- everything is IF NOT EXISTS / CREATE OR REPLACE)."
echo "  2. Restart your app (pm2 restart ... or however you run it in prod)."
echo "  3. Visit /projects -- create a project, add teammates, add tasks, drag"
echo "     cards between columns, click a card to comment/edit/delete it."
