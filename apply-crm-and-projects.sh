#!/usr/bin/env bash
# Sanestix OS -- Phase 5: full CRM module (Companies, Contacts, Leads/Pipeline,
# activity log, follow-up tasks) + a minimal real Projects module. A lead
# marked "Won" auto-creates a draft Project, linking CRM -> Projects for real.
#
# Run from the ROOT of your repo (same place package.json lives).
set -e

mkdir -p src/app/crm src/app/crm/companies src/app/crm/contacts src/app/crm/leads/[id] src/app/crm/tasks src/app/projects src/components/crm src/components/finance src/components/layout src/lib src/lib/supabase supabase

echo "1/18 -- Writing supabase/schema-phase5-crm-and-projects.sql..."
cat > 'supabase/schema-phase5-crm-and-projects.sql' << 'SANESTIX_EOF'
-- Sanestix OS — Phase 5 schema (CRM + minimal real Projects)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is IF NOT EXISTS / CREATE OR REPLACE.
--
-- Adds:
--   crm_companies        — organizations you sell to
--   crm_contacts         — people at those companies
--   crm_leads            — the pipeline itself (stage, value, owner)
--   crm_lead_activities  — notes/calls/emails/meetings/stage-change log per lead
--   crm_lead_tasks       — follow-up reminders per lead, with due dates
--   projects             — minimal real Projects table; a lead marked "won"
--                          auto-creates a draft row here (see app/crm/actions.ts)

-- ---------------------------------------------------------------------------
-- 1. Companies
-- ---------------------------------------------------------------------------
create table if not exists public.crm_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry text,
  website text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Contacts — a person, optionally tied to a company
-- ---------------------------------------------------------------------------
create table if not exists public.crm_contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.crm_companies (id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  title text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Leads — the pipeline. Stage list mirrors the dashboard's Sales Funnel
--    chart exactly (New → Contacted → Qualified → Proposal → Won/Lost) so
--    lib/supabase/queries.ts can build that chart straight from counts here.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company_id uuid references public.crm_companies (id) on delete set null,
  contact_id uuid references public.crm_contacts (id) on delete set null,
  stage text not null default 'new'
    check (stage in ('new', 'contacted', 'qualified', 'proposal', 'won', 'lost')),
  value numeric(12, 2) not null default 0 check (value >= 0),
  source text,
  owner_id uuid references public.profiles (id),
  expected_close_date date,
  notes text,
  converted_project_id uuid,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists crm_leads_set_updated_at on public.crm_leads;
create trigger crm_leads_set_updated_at
  before update on public.crm_leads
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. Lead activity log — notes, calls, emails, meetings, stage changes.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.crm_leads (id) on delete cascade,
  kind text not null default 'note'
    check (kind in ('note', 'call', 'email', 'meeting', 'stage_change')),
  content text not null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. Lead follow-up tasks — "call back Thursday" style reminders.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_lead_tasks (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.crm_leads (id) on delete cascade,
  title text not null,
  due_date date not null,
  done boolean not null default false,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. Projects — minimal real table. A "won" lead auto-creates a draft row
--    here (source_lead_id links back), so CRM → Projects is a real handoff
--    instead of two disconnected modules. Projects module can grow later
--    (tasks, members, comments) without touching this table's shape.
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_name text,
  company_id uuid references public.crm_companies (id) on delete set null,
  status text not null default 'on_track'
    check (status in ('on_track', 'at_risk', 'delayed', 'completed')),
  source_lead_id uuid references public.crm_leads (id) on delete set null,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.crm_leads
  add constraint crm_leads_converted_project_id_fkey
  foreign key (converted_project_id) references public.projects (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 7. RLS — same internal-tool pattern as every other table in this app:
--    any signed-in user can read/write. Tighten later once real staff
--    roles exist.
-- ---------------------------------------------------------------------------
alter table public.crm_companies enable row level security;
alter table public.crm_contacts enable row level security;
alter table public.crm_leads enable row level security;
alter table public.crm_lead_activities enable row level security;
alter table public.crm_lead_tasks enable row level security;
alter table public.projects enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['crm_companies', 'crm_contacts', 'crm_leads', 'crm_lead_activities', 'crm_lead_tasks', 'projects']
  loop
    execute format('drop policy if exists "Authenticated users can read %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can read %1$s" on public.%1$s for select to authenticated using (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can write %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can write %1$s" on public.%1$s for insert to authenticated with check (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can update %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can update %1$s" on public.%1$s for update to authenticated using (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can delete %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can delete %1$s" on public.%1$s for delete to authenticated using (true)',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Helpful indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_crm_contacts_company_id on public.crm_contacts (company_id);
create index if not exists idx_crm_leads_company_id on public.crm_leads (company_id);
create index if not exists idx_crm_leads_contact_id on public.crm_leads (contact_id);
create index if not exists idx_crm_leads_stage on public.crm_leads (stage);
create index if not exists idx_crm_lead_activities_lead_id on public.crm_lead_activities (lead_id);
create index if not exists idx_crm_lead_tasks_lead_id on public.crm_lead_tasks (lead_id);
create index if not exists idx_crm_lead_tasks_due_date on public.crm_lead_tasks (due_date) where not done;
create index if not exists idx_projects_source_lead_id on public.projects (source_lead_id);
SANESTIX_EOF

echo "2/18 -- Writing src/lib/types.ts..."
cat > 'src/lib/types.ts' << 'SANESTIX_EOF'
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

echo "3/18 -- Writing src/lib/auth-confirm.ts..."
cat > 'src/lib/auth-confirm.ts' << 'SANESTIX_EOF'
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

/**
 * Shared "re-enter your password to delete this" guard, used by every
 * destructive server action across Finance, CRM, and Projects. Redirects
 * (throws) on any failure; only returns when the password was correct.
 */
export async function confirmPasswordOrRedirect(
  password: string,
  redirectTo: string
): Promise<{ supabase: Awaited<ReturnType<typeof createClient>>; user: { id: string; email: string } }> {
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

  return { supabase, user: { id: user.id, email: user.email } };
}
SANESTIX_EOF

echo "4/18 -- Writing src/lib/supabase/queries.ts..."
cat > 'src/lib/supabase/queries.ts' << 'SANESTIX_EOF'
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

echo "5/18 -- Writing src/lib/data.ts..."
cat > 'src/lib/data.ts' << 'SANESTIX_EOF'
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

echo "6/18 -- Writing src/components/finance/register-status-form.tsx..."
cat > 'src/components/finance/register-status-form.tsx' << 'SANESTIX_EOF'
"use client";

import { StatusPill } from "@/components/ui/status-pill";

type Tone = "primary" | "success" | "warning" | "error" | "neutral";

export function RegisterStatusForm({
  idFieldName,
  idValue,
  status,
  tone,
  options,
  action,
  extraFields,
}: {
  idFieldName: string;
  idValue: string;
  status: string;
  tone: Tone;
  options: { value: string; label: string }[];
  action: (formData: FormData) => void;
  extraFields?: Record<string, string>;
}) {
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name={idFieldName} value={idValue} />
      {extraFields &&
        Object.entries(extraFields).map(([name, value]) => (
          <input key={name} type="hidden" name={name} value={value} />
        ))}
      <StatusPill tone={tone}>{status}</StatusPill>
      <select
        name="status"
        defaultValue={status}
        onChange={(e) => e.currentTarget.form?.requestSubmit()}
        className="border border-outline-variant bg-background px-1.5 py-1 font-mono-data text-[10px] uppercase tracking-wider focus:border-primary focus:outline-none"
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </form>
  );
}
SANESTIX_EOF

echo "7/18 -- Writing src/components/layout/sidebar.tsx..."
cat > 'src/components/layout/sidebar.tsx' << 'SANESTIX_EOF'
"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Wallet,
  Kanban,
  Users,
  FileText,
  Settings,
  HelpCircle,
  LogOut,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { LogoutButton } from "@/components/auth/logout-button";

const NAV_ITEMS = [
  { label: "Dashboard", icon: LayoutDashboard, href: "/" },
  { label: "Finance", icon: Wallet, href: "/finance" },
  { label: "Projects", icon: Kanban, href: "/projects" },
  { label: "CRM", icon: Users, href: "/crm" },
  { label: "Reports", icon: FileText, href: "/reports" },
  { label: "Settings", icon: Settings, href: "/settings" },
];

// Any nav item with a matching key here gets an expandable submenu (desktop
// flyout + mobile bottom-sheet), same mechanism the old Finance-only bar
// used — just generalized so CRM (and future modules) can have one too.
const SUB_ITEMS: Record<string, { label: string; href: string }[]> = {
  Finance: [
    { label: "Overview", href: "/finance" },
    { label: "Income", href: "/finance/income" },
    { label: "Expenses", href: "/finance/expenses" },
    { label: "Transactions", href: "/finance/transactions" },
    { label: "Invoices", href: "/finance/invoices" },
    { label: "Investments", href: "/finance/investments" },
    { label: "Reimbursements", href: "/finance/reimbursements" },
    { label: "Founder Entry", href: "/finance/loans" },
    { label: "Profit Split", href: "/finance/profit-split" },
    { label: "Reports", href: "/finance/reports" },
    { label: "Vendors", href: "/finance/vendors" },
    { label: "Employees", href: "/finance/employees" },
    { label: "Subscriptions", href: "/finance/subscriptions" },
    { label: "Assets", href: "/finance/assets" },
    { label: "Debts", href: "/finance/debts" },
  ],
  CRM: [
    { label: "Pipeline", href: "/crm" },
    { label: "Companies", href: "/crm/companies" },
    { label: "Contacts", href: "/crm/contacts" },
    { label: "Tasks", href: "/crm/tasks" },
  ],
};

function getInitials(email?: string) {
  if (!email) return "SU";
  return email
    .split("@")[0]
    .split(/[._-]/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

export function Sidebar({ userEmail }: { userEmail?: string }) {
  const pathname = usePathname();
  const [expandedMenu, setExpandedMenu] = useState<string | null>("Finance");
  const [mobileMenuRequest, setMobileMenuRequest] = useState<string | null>(null);

  const activeItem = NAV_ITEMS.find(({ href }) =>
    href === "/" ? pathname === "/" : pathname.startsWith(href)
  );

  // Derived, not synced: the mobile sheet is only actually open if the
  // requested module is still the one the user is on. Navigating away
  // (via any link, not just this one) closes it automatically without
  // needing a useEffect + setState round-trip.
  const mobileMenuOpen = mobileMenuRequest && activeItem?.label === mobileMenuRequest ? mobileMenuRequest : null;

  return (
    <>
      <aside className="fixed left-0 top-0 z-50 hidden h-full w-[248px] flex-col border-r border-outline-variant bg-surface py-4 lg:flex">
        <div className="mb-8 px-5">
          <span className="text-[20px] font-bold tracking-tight text-primary">
            Sanestix
          </span>
          <p className="mt-1 text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Operations OS
          </p>
        </div>

        <nav className="sidebar-scroll flex-1 space-y-1 overflow-y-auto px-3">
          {NAV_ITEMS.map(({ label, icon: Icon, href }) => {
            const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
            const subItems = SUB_ITEMS[label];
            const hasSubItems = Boolean(subItems);
            const isExpanded = expandedMenu === label;

            return (
              <div key={label}>
                <Link
                  href={href}
                  onClick={(e) => {
                    if (!hasSubItems) return;
                    if (active) {
                      // Already on this module: clicking anywhere on the row
                      // just toggles the submenu open/closed.
                      e.preventDefault();
                      setExpandedMenu((v) => (v === label ? null : label));
                    } else {
                      // Navigating into this module for the first time: open it.
                      setExpandedMenu(label);
                    }
                  }}
                  className={cn(
                    "group flex w-full items-center gap-3 px-3 py-2.5 text-left text-[13px] font-medium transition-all duration-200 ease-out",
                    active
                      ? "border-l-2 border-primary bg-primary/[0.06] text-primary"
                      : "border-l-2 border-transparent text-on-surface-variant hover:translate-x-0.5 hover:border-primary/40 hover:bg-primary/[0.04] hover:text-on-surface"
                  )}
                >
                  <Icon
                    size={17}
                    strokeWidth={2}
                    className="transition-transform duration-200 ease-out group-hover:scale-110"
                  />
                  <span className="flex-1">{label}</span>
                  {hasSubItems && (
                    <ChevronDown
                      size={14}
                      className={cn(
                        "transition-transform duration-200 ease-out",
                        isExpanded && "rotate-180"
                      )}
                    />
                  )}
                </Link>

                {hasSubItems && active && isExpanded && (
                  <div className="ml-[26px] mt-1 space-y-0.5 border-l border-outline-variant pl-3">
                    {subItems.map((tab) => {
                      const tabActive = pathname === tab.href;
                      return (
                        <Link
                          key={tab.href}
                          href={tab.href}
                          className={cn(
                            "block px-2 py-1.5 font-mono-data text-[11px] uppercase tracking-wider transition-all duration-200 ease-out",
                            tabActive
                              ? "text-primary"
                              : "text-on-surface-variant hover:translate-x-0.5 hover:text-on-surface"
                          )}
                        >
                          {tab.label}
                        </Link>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </nav>

        <div className="space-y-1 px-3 pt-4">
          <Link
            href="/help"
            className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
          >
            <HelpCircle size={15} />
            Help
          </Link>
          <LogoutButton className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-error">
            <LogOut size={15} />
            Sign out
          </LogoutButton>

          <div className="mt-3 flex items-center justify-between border border-outline-variant bg-background px-3 py-2.5">
            <div className="flex min-w-0 items-center gap-2.5">
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-primary/20 bg-primary/10 text-[11px] font-semibold text-primary">
                {getInitials(userEmail)}
              </div>
              <div className="flex min-w-0 flex-col leading-none">
                <span className="truncate text-[11px] font-semibold text-on-surface">
                  {userEmail ?? "Signed in"}
                </span>
                <span className="mt-1 text-[9px] uppercase tracking-wider text-on-surface-variant">
                  Team member
                </span>
              </div>
            </div>
          </div>
        </div>
      </aside>

      {/* Mobile submenu drawer — backdrop + sheet, sits above the bottom tab bar */}
      {mobileMenuOpen && SUB_ITEMS[mobileMenuOpen] && (
        <>
          <button
            aria-label={`Close ${mobileMenuOpen} menu`}
            onClick={() => setMobileMenuRequest(null)}
            className="fixed inset-0 z-40 bg-black/40 lg:hidden"
          />
          <div className="fixed inset-x-0 bottom-[56px] z-50 max-h-[60vh] overflow-y-auto border-t border-outline-variant bg-surface pb-2 lg:hidden">
            <div className="flex items-center justify-between px-4 py-3">
              <span className="font-mono-data text-[11px] uppercase tracking-widest text-on-surface-variant/70">
                {mobileMenuOpen}
              </span>
              <button
                onClick={() => setMobileMenuRequest(null)}
                className="text-on-surface-variant"
                aria-label="Close"
              >
                <ChevronUp size={16} />
              </button>
            </div>
            <div className="grid grid-cols-2 gap-1 px-3 pb-3">
              {SUB_ITEMS[mobileMenuOpen].map((tab) => {
                const tabActive = pathname === tab.href;
                return (
                  <Link
                    key={tab.href}
                    href={tab.href}
                    onClick={() => setMobileMenuRequest(null)}
                    className={cn(
                      "border border-outline-variant px-3 py-2.5 text-center font-mono-data text-[11px] uppercase tracking-wider transition-colors",
                      tabActive
                        ? "border-primary/40 bg-primary/[0.06] text-primary"
                        : "text-on-surface-variant hover:text-on-surface"
                    )}
                  >
                    {tab.label}
                  </Link>
                );
              })}
            </div>
          </div>
        </>
      )}

      <nav className="fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t border-outline-variant bg-surface/95 px-2 py-1.5 backdrop-blur lg:hidden">
        {NAV_ITEMS.slice(0, 5).map(({ label, icon: Icon, href }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          const hasSubItems = Boolean(SUB_ITEMS[label]);

          return (
            <Link
              key={label}
              href={href}
              onClick={(e) => {
                if (!hasSubItems) return;
                if (active) {
                  // Already on this module: tap toggles the drawer instead
                  // of re-navigating.
                  e.preventDefault();
                  setMobileMenuRequest((v) => (v === label ? null : label));
                } else {
                  setMobileMenuRequest(label);
                }
              }}
              className={cn(
                "flex min-w-0 flex-col items-center gap-1 px-1 py-2 text-[10px] font-medium transition-colors",
                active ? "text-primary" : "text-on-surface-variant"
              )}
            >
              <Icon size={18} strokeWidth={2} />
              <span className="w-full truncate text-center">{label}</span>
            </Link>
          );
        })}
      </nav>
    </>
  );
}
SANESTIX_EOF

echo "8/18 -- Writing src/components/crm/task-toggle-checkbox.tsx..."
cat > 'src/components/crm/task-toggle-checkbox.tsx' << 'SANESTIX_EOF'
"use client";

export function TaskToggleCheckbox({
  action,
  taskId,
  done,
  redirectTo,
}: {
  action: (formData: FormData) => void;
  taskId: string;
  done: boolean;
  redirectTo: string;
}) {
  return (
    <form action={action}>
      <input type="hidden" name="taskId" value={taskId} />
      <input type="hidden" name="done" value={String(done)} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <button
        type="submit"
        aria-label={done ? "Mark task not done" : "Mark task done"}
        className={
          done
            ? "flex h-4 w-4 items-center justify-center border border-success bg-success text-[10px] text-white"
            : "h-4 w-4 border border-outline-variant bg-background transition hover:border-primary"
        }
      >
        {done ? "✓" : ""}
      </button>
    </form>
  );
}
SANESTIX_EOF

echo "9/18 -- Writing src/app/crm/actions.ts..."
cat > 'src/app/crm/actions.ts' << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { confirmPasswordOrRedirect } from "@/lib/auth-confirm";
import { recordActivity } from "@/lib/audit";
import { LEAD_STAGES } from "@/lib/types";

const VALID_STAGES = LEAD_STAGES.map((s) => s.value);

// ---------------------------------------------------------------------------
// Companies
// ---------------------------------------------------------------------------

export async function addCompany(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const industry = String(formData.get("industry") ?? "") || null;
  const website = String(formData.get("website") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!name) redirect("/crm/companies?error=Please enter a company name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_companies")
    .insert({ name, industry, website, notes, created_by: user?.id ?? null })
    .select("id")
    .single();

  if (error) redirect(`/crm/companies?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_companies",
    entityId: inserted?.id ?? null,
    summary: `Company "${name}" added`,
    notify: false,
  });

  revalidatePath("/crm/companies");
  redirect("/crm/companies");
}

export async function deleteCompany(formData: FormData) {
  const companyId = String(formData.get("companyId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/companies";

  if (!companyId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing company id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_companies")
    .select("name")
    .eq("id", companyId)
    .maybeSingle();
  const { error } = await supabase.from("crm_companies").delete().eq("id", companyId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_companies",
    entityId: companyId,
    summary: `Company "${existing?.name ?? companyId}" deleted`,
    notify: true,
    notifyLink: "/crm/companies",
  });

  revalidatePath("/crm/companies");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Contacts
// ---------------------------------------------------------------------------

export async function addContact(formData: FormData) {
  const fullName = String(formData.get("fullName") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const email = String(formData.get("email") ?? "") || null;
  const phone = String(formData.get("phone") ?? "") || null;
  const title = String(formData.get("title") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!fullName) redirect("/crm/contacts?error=Please enter a contact name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_contacts")
    .insert({
      full_name: fullName,
      company_id: companyId,
      email,
      phone,
      title,
      notes,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm/contacts?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_contacts",
    entityId: inserted?.id ?? null,
    summary: `Contact "${fullName}" added`,
    notify: false,
  });

  revalidatePath("/crm/contacts");
  redirect("/crm/contacts");
}

export async function deleteContact(formData: FormData) {
  const contactId = String(formData.get("contactId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/contacts";

  if (!contactId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing contact id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_contacts")
    .select("full_name")
    .eq("id", contactId)
    .maybeSingle();
  const { error } = await supabase.from("crm_contacts").delete().eq("id", contactId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_contacts",
    entityId: contactId,
    summary: `Contact "${existing?.full_name ?? contactId}" deleted`,
    notify: true,
    notifyLink: "/crm/contacts",
  });

  revalidatePath("/crm/contacts");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Leads (the pipeline)
// ---------------------------------------------------------------------------

export async function addLead(formData: FormData) {
  const title = String(formData.get("title") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const contactId = String(formData.get("contactId") ?? "") || null;
  const value = Number(formData.get("value") ?? 0);
  const source = String(formData.get("source") ?? "") || null;
  const expectedCloseDate = String(formData.get("expectedCloseDate") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!title || value < 0) {
    redirect("/crm?error=Please fill in the lead title with a valid value");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_leads")
    .insert({
      title,
      company_id: companyId,
      contact_id: contactId,
      value,
      source,
      owner_id: user?.id ?? null,
      expected_close_date: expectedCloseDate,
      notes,
      stage: "new",
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_leads",
    entityId: inserted?.id ?? null,
    summary: `New lead "${title}"`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect("/crm");
}

/**
 * Move a lead to a new pipeline stage. Moving a lead to "won" auto-creates
 * a draft Project row and links it back via converted_project_id — this is
 * the real CRM → Projects handoff (not just two disconnected modules).
 * Safe to call repeatedly: if the lead was already won, it won't create a
 * second project.
 */
export async function updateLeadStage(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const stage = String(formData.get("stage") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm");

  if (!leadId || !VALID_STAGES.includes(stage as (typeof VALID_STAGES)[number])) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid stage update")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: lead } = await supabase
    .from("crm_leads")
    .select("id, title, value, company_id, converted_project_id, stage")
    .eq("id", leadId)
    .maybeSingle();

  if (!lead) redirect(`${redirectTo}?error=${encodeURIComponent("Lead not found")}`);

  const { error } = await supabase.from("crm_leads").update({ stage }).eq("id", leadId);
  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind: "stage_change",
    content: `Stage changed to "${stage}"`,
    created_by: user?.id ?? null,
  });

  let projectId: string | null = null;

  if (stage === "won" && !lead.converted_project_id) {
    const { data: project, error: projectError } = await supabase
      .from("projects")
      .insert({
        name: lead.title,
        company_id: lead.company_id,
        status: "on_track",
        source_lead_id: leadId,
        notes: `Auto-created from won lead (deal value ${lead.value}).`,
        created_by: user?.id ?? null,
      })
      .select("id")
      .single();

    if (!projectError && project) {
      projectId = project.id;
      await supabase.from("crm_leads").update({ converted_project_id: project.id }).eq("id", leadId);
    }
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_leads",
    entityId: leadId,
    summary: projectId
      ? `Lead "${lead.title}" won — draft project created`
      : `Lead "${lead.title}" moved to ${stage}`,
    notify: stage === "won",
    notifyLink: projectId ? "/projects" : "/crm",
  });

  revalidatePath("/crm");
  revalidatePath(`/crm/leads/${leadId}`);
  revalidatePath("/projects");
  redirect(redirectTo);
}

export async function deleteLead(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm";

  if (!leadId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing lead id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_leads")
    .select("title")
    .eq("id", leadId)
    .maybeSingle();
  const { error } = await supabase.from("crm_leads").delete().eq("id", leadId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_leads",
    entityId: leadId,
    summary: `Lead "${existing?.title ?? leadId}" deleted`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead notes / activity log
// ---------------------------------------------------------------------------

export async function addLeadNote(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const kind = String(formData.get("kind") ?? "note");
  const content = String(formData.get("content") ?? "").trim();
  const redirectTo = `/crm/leads/${leadId}`;

  if (!leadId || !content) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please write a note before saving")}`);
  }
  if (!["note", "call", "email", "meeting"].includes(kind)) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid note type")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind,
    content,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  // Touch updated_at so the lead surfaces near the top of "recently active".
  await supabase.from("crm_leads").update({ updated_at: new Date().toISOString() }).eq("id", leadId);

  revalidatePath(redirectTo);
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead follow-up tasks
// ---------------------------------------------------------------------------

export async function addLeadTask(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const dueDate = String(formData.get("dueDate") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? `/crm/leads/${leadId}`);

  if (!leadId || !title || !dueDate) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please fill in the task title and due date")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_tasks").insert({
    lead_id: leadId,
    title,
    due_date: dueDate,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function toggleLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const done = formData.get("done") === "true";
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").update({ done: !done }).eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function deleteLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").delete().eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}
SANESTIX_EOF

echo "10/18 -- Writing src/app/crm/page.tsx..."
cat > 'src/app/crm/page.tsx' << 'SANESTIX_EOF'
import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getCrmLeads, getCrmCompanies, getCrmContacts } from "@/lib/supabase/queries";
import { addLead, updateLeadStage, deleteLead } from "@/app/crm/actions";
import { LEAD_STAGES, type LeadStage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

const BOARD_STAGES = LEAD_STAGES.filter((s) => s.value !== "lost");

export default async function CrmPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [leads, companies, contacts] = await Promise.all([
    getCrmLeads(),
    getCrmCompanies(),
    getCrmContacts(),
  ]);

  const openLeads = leads.filter((l) => l.stage !== "won" && l.stage !== "lost");
  const pipelineValue = openLeads.reduce((sum, l) => sum + l.value, 0);
  const wonThisMonth = leads.filter((l) => {
    if (l.stage !== "won") return false;
    const d = new Date(l.updatedAt);
    const now = new Date();
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  }).length;
  const lostCount = leads.filter((l) => l.stage === "lost").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">CRM Pipeline</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Leads from intake to closed work. Moving a lead to Won creates a draft project
            automatically.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Open leads
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-primary">{openLeads.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Pipeline value
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(pipelineValue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Won this month
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{wonThisMonth}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Lost
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {lostCount}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <Card className="p-6 lg:col-span-1">
          <CardTitle>Add a lead</CardTitle>
          <CardDescription>New pipeline entry, starts at stage &quot;New&quot;.</CardDescription>

          <form action={addLead} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Lead title
              </label>
              <input
                type="text"
                name="title"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Marwaa Memorials — Website"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Company
              </label>
              <select
                name="companyId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact
              </label>
              <select
                name="contactId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.fullName}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Deal value (PKR)
              </label>
              <input
                type="number"
                name="value"
                min="0"
                step="0.01"
                defaultValue="0"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Source
              </label>
              <input
                type="text"
                name="source"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Website form, referral"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Expected close date
              </label>
              <input
                type="date"
                name="expectedCloseDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add lead
            </button>
          </form>

          <div className="mt-6 flex flex-col gap-2 border-t border-outline-variant pt-4 text-[11px]">
            <Link href="/crm/companies" className="text-on-surface-variant hover:text-primary">
              Manage companies →
            </Link>
            <Link href="/crm/contacts" className="text-on-surface-variant hover:text-primary">
              Manage contacts →
            </Link>
            <Link href="/crm/tasks" className="text-on-surface-variant hover:text-primary">
              Follow-up tasks →
            </Link>
          </div>
        </Card>

        <div className="lg:col-span-3">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {BOARD_STAGES.map((stage) => {
              const stageLeads = leads.filter((l) => l.stage === stage.value);
              return (
                <div key={stage.value} className="flex min-w-0 flex-col">
                  <div className="mb-2 flex items-center justify-between px-1">
                    <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                      {stage.label}
                    </span>
                    <span className="font-mono-data text-[11px] text-on-surface-variant/70">
                      {stageLeads.length}
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-2">
                    {stageLeads.length === 0 && (
                      <Card className="p-3 text-center text-[11px] text-on-surface-variant/60">
                        Empty
                      </Card>
                    )}
                    {stageLeads.map((lead) => (
                      <Card key={lead.id} className="p-3">
                        <Link
                          href={`/crm/leads/${lead.id}`}
                          className="block text-[13px] font-medium text-on-surface hover:text-primary"
                        >
                          {lead.title}
                        </Link>
                        <p className="mt-0.5 truncate text-[11px] text-on-surface-variant">
                          {lead.companyName ?? lead.contactName ?? "—"}
                        </p>
                        <p className="mt-1 font-mono-data text-[12px] font-semibold text-success">
                          {formatCurrency(lead.value)}
                        </p>
                        {lead.overdueTaskCount > 0 && (
                          <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-error">
                            {lead.overdueTaskCount} overdue task{lead.overdueTaskCount > 1 ? "s" : ""}
                          </p>
                        )}
                        <div className="mt-2 flex items-center justify-between gap-2">
                          <RegisterStatusForm
                            idFieldName="leadId"
                            idValue={lead.id}
                            status={lead.stage}
                            tone={STAGE_TONE[lead.stage]}
                            options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                            action={updateLeadStage}
                            extraFields={{ redirectTo: "/crm" }}
                          />
                          <RegisterDeleteButton
                            action={deleteLead}
                            idFieldName="leadId"
                            idValue={lead.id}
                            redirectTo="/crm"
                            label="lead"
                          />
                        </div>
                      </Card>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "11/18 -- Writing src/app/crm/loading.tsx..."
cat > 'src/app/crm/loading.tsx' << 'SANESTIX_EOF'
export default function CrmLoading() {
  return (
    <div className="animate-pulse space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="h-7 w-56 rounded-[2px] bg-surface-container-high" />
      <div className="h-4 w-80 rounded-[2px] bg-surface-container-high" />
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-20 rounded-[2px] border border-outline-variant bg-surface" />
        ))}
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <div className="h-96 rounded-[2px] border border-outline-variant bg-surface" />
        <div className="h-96 rounded-[2px] border border-outline-variant bg-surface lg:col-span-3" />
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "12/18 -- Writing src/app/crm/error.tsx..."
cat > 'src/app/crm/error.tsx' << 'SANESTIX_EOF'
"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { RefreshCw, AlertTriangle, ArrowLeft } from "lucide-react";

export default function CrmError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("CRM module error:", error);
  }, [error]);

  const hint = useMemo(() => {
    const message = error.message ?? "";

    if (/relation .* does not exist/i.test(message) || /does not exist/i.test(message)) {
      return "This table hasn't been created in Supabase yet. Run supabase/schema-phase5-crm-and-projects.sql in the Supabase SQL editor, then reload.";
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
          <h1 className="text-[15px] font-semibold tracking-tight">This CRM page couldn&apos;t load</h1>
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
            href="/crm"
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <ArrowLeft size={14} />
            Back to CRM
          </Link>
        </div>
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "13/18 -- Writing src/app/crm/companies/page.tsx..."
cat > 'src/app/crm/companies/page.tsx' << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getCrmCompanies } from "@/lib/supabase/queries";
import { addCompany, deleteCompany } from "@/app/crm/actions";

export const dynamic = "force-dynamic";

export default async function CompaniesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const companies = await getCrmCompanies();

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM", "Companies"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Companies</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Organizations you sell to — one company can have many contacts and leads.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a company</CardTitle>
          <CardDescription>Register a new organization.</CardDescription>

          <form action={addCompany} className="mt-4 space-y-3">
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
                placeholder="e.g. Northwind Logistics"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Industry
              </label>
              <input
                type="text"
                name="industry"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Website
              </label>
              <input
                type="text"
                name="website"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Notes
              </label>
              <textarea
                name="notes"
                rows={3}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add company
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Company Register</CardTitle>
          <CardDescription>All companies, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[640px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Industry</th>
                  <th className="pb-2 pr-4">Contacts</th>
                  <th className="pb-2 pr-4">Leads</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {companies.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No companies recorded yet.
                    </td>
                  </tr>
                )}
                {companies.map((c) => (
                  <tr key={c.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">
                      {c.website ? (
                        <a
                          href={c.website.startsWith("http") ? c.website : `https://${c.website}`}
                          target="_blank"
                          rel="noreferrer"
                          className="hover:text-primary hover:underline"
                        >
                          {c.name}
                        </a>
                      ) : (
                        c.name
                      )}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{c.industry ?? "—"}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {c.contactCount}
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {c.leadCount}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteCompany}
                          idFieldName="companyId"
                          idValue={c.id}
                          redirectTo="/crm/companies"
                          label="company"
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

echo "14/18 -- Writing src/app/crm/contacts/page.tsx..."
cat > 'src/app/crm/contacts/page.tsx' << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getCrmContacts, getCrmCompanies } from "@/lib/supabase/queries";
import { addContact, deleteContact } from "@/app/crm/actions";

export const dynamic = "force-dynamic";

export default async function ContactsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [contacts, companies] = await Promise.all([getCrmContacts(), getCrmCompanies()]);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM", "Contacts"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Contacts</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          People at the companies you sell to. Optionally tied to a company.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a contact</CardTitle>
          <CardDescription>Register a new person.</CardDescription>

          <form action={addContact} className="mt-4 space-y-3">
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
                placeholder="e.g. N. Aslam"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Company
              </label>
              <select
                name="companyId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Title
              </label>
              <input
                type="text"
                name="title"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Email
              </label>
              <input
                type="email"
                name="email"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Phone
              </label>
              <input
                type="text"
                name="phone"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Notes
              </label>
              <textarea
                name="notes"
                rows={3}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add contact
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Contact Register</CardTitle>
          <CardDescription>All contacts, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Company</th>
                  <th className="pb-2 pr-4">Title</th>
                  <th className="pb-2 pr-4">Contact</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {contacts.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No contacts recorded yet.
                    </td>
                  </tr>
                )}
                {contacts.map((c) => (
                  <tr key={c.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{c.fullName}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{c.companyName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{c.title ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {c.email ?? c.phone ?? "—"}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteContact}
                          idFieldName="contactId"
                          idValue={c.id}
                          redirectTo="/crm/contacts"
                          label="contact"
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

echo "15/18 -- Writing src/app/crm/tasks/page.tsx..."
cat > 'src/app/crm/tasks/page.tsx' << 'SANESTIX_EOF'
import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { TaskToggleCheckbox } from "@/components/crm/task-toggle-checkbox";
import { getOpenLeadTasks } from "@/lib/supabase/queries";
import { toggleLeadTask, deleteLeadTask } from "@/app/crm/actions";

export const dynamic = "force-dynamic";

export default async function CrmTasksPage() {
  const tasks = await getOpenLeadTasks();
  const overdueTasks = tasks.filter((t) => t.overdue);
  const upcomingTasks = tasks.filter((t) => !t.overdue);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM", "Tasks"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Follow-up Tasks</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Every open reminder across your pipeline, soonest due first.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueTasks.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Upcoming
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{upcomingTasks.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>All open tasks</CardTitle>
        <CardDescription>Check one off to mark it done, or delete it.</CardDescription>

        <div className="mt-4 divide-y divide-outline-variant">
          {tasks.length === 0 && (
            <p className="py-6 text-center text-[13px] text-on-surface-variant">
              No open follow-up tasks. Add one from a lead&apos;s detail page.
            </p>
          )}
          {tasks.map((t) => (
            <div key={t.id} className="flex items-center gap-3 py-3">
              <TaskToggleCheckbox
                action={toggleLeadTask}
                taskId={t.id}
                done={t.done}
                redirectTo="/crm/tasks"
              />
              <div className="min-w-0 flex-1">
                <p className="truncate text-[13px] text-on-surface">{t.title}</p>
                {t.leadId && (
                  <Link
                    href={`/crm/leads/${t.leadId}`}
                    className="text-[11px] text-on-surface-variant hover:text-primary"
                  >
                    {t.leadTitle ?? "View lead"} →
                  </Link>
                )}
              </div>
              <StatusPill tone={t.overdue ? "error" : "neutral"}>
                {new Date(t.dueDate).toLocaleDateString(undefined, {
                  month: "short",
                  day: "numeric",
                })}
              </StatusPill>
              <form action={deleteLeadTask}>
                <input type="hidden" name="taskId" value={t.id} />
                <input type="hidden" name="redirectTo" value="/crm/tasks" />
                <button
                  type="submit"
                  aria-label="Delete task"
                  className="px-1.5 py-1 text-on-surface-variant transition hover:text-error"
                >
                  ✕
                </button>
              </form>
            </div>
          ))}
        </div>
      </Card>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "16/18 -- Writing src/app/crm/leads/[id]/page.tsx..."
cat > 'src/app/crm/leads/[id]/page.tsx' << 'SANESTIX_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { TaskToggleCheckbox } from "@/components/crm/task-toggle-checkbox";
import { getCrmLead, getLeadActivities, getOpenLeadTasks } from "@/lib/supabase/queries";
import {
  updateLeadStage,
  deleteLead,
  addLeadNote,
  addLeadTask,
  toggleLeadTask,
  deleteLeadTask,
} from "@/app/crm/actions";
import { LEAD_STAGES, type LeadStage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

const ACTIVITY_LABEL: Record<string, string> = {
  note: "Note",
  call: "Call",
  email: "Email",
  meeting: "Meeting",
  stage_change: "Stage change",
};

export default async function LeadDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { id } = await params;
  const search = await searchParams;
  const lead = await getCrmLead(id);
  if (!lead) notFound();

  const [activities, allOpenTasks] = await Promise.all([
    getLeadActivities(id),
    getOpenLeadTasks(),
  ]);
  const leadTasks = allOpenTasks.filter((t) => t.leadId === id);
  const redirectTo = `/crm/leads/${id}`;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM", lead.title]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <Link href="/crm" className="text-[11px] text-on-surface-variant hover:text-primary">
            ← Back to pipeline
          </Link>
          <h1 className="mt-2 text-[28px] font-bold tracking-tight text-on-surface">{lead.title}</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            {lead.companyName ?? "No company"} · {lead.contactName ?? "No contact"}
          </p>
        </div>
        <RegisterDeleteButton
          action={deleteLead}
          idFieldName="leadId"
          idValue={lead.id}
          redirectTo="/crm"
          label="lead"
        />
      </div>

      {lead.convertedProjectId && (
        <Card className="flex items-center justify-between border-success/30 bg-success/[0.06] p-4">
          <p className="text-[13px] text-on-surface">
            This lead was won and auto-created a draft project.
          </p>
          <Link
            href="/projects"
            className="inline-flex items-center gap-1 text-[12px] font-mono-data uppercase tracking-wider text-success hover:brightness-110"
          >
            View project <ArrowRight size={14} />
          </Link>
        </Card>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Details</CardTitle>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Stage</span>
              <RegisterStatusForm
                idFieldName="leadId"
                idValue={lead.id}
                status={lead.stage}
                tone={STAGE_TONE[lead.stage]}
                options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                action={updateLeadStage}
                extraFields={{ redirectTo }}
              />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Value</span>
              <span className="font-mono-data font-semibold text-success">
                {formatCurrency(lead.value)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Owner</span>
              <span className="text-on-surface">{lead.ownerName ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Source</span>
              <span className="text-on-surface">{lead.source ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Expected close</span>
              <span className="font-mono-data text-on-surface">
                {lead.expectedCloseDate
                  ? new Date(lead.expectedCloseDate).toLocaleDateString()
                  : "—"}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Contact email</span>
              <span className="text-on-surface">{lead.contactEmail ?? "—"}</span>
            </div>
            {lead.notes && (
              <div className="border-t border-outline-variant pt-3">
                <span className="text-on-surface-variant">Notes</span>
                <p className="mt-1 text-on-surface">{lead.notes}</p>
              </div>
            )}
          </div>

          <div className="mt-6 border-t border-outline-variant pt-4">
            <CardTitle>Follow-up tasks</CardTitle>
            <div className="mt-3 space-y-2">
              {leadTasks.length === 0 && (
                <p className="text-[12px] text-on-surface-variant">No open tasks.</p>
              )}
              {leadTasks.map((t) => (
                <div key={t.id} className="flex items-center gap-2 text-[12px]">
                  <TaskToggleCheckbox
                    action={toggleLeadTask}
                    taskId={t.id}
                    done={t.done}
                    redirectTo={redirectTo}
                  />
                  <span className="min-w-0 flex-1 truncate text-on-surface">{t.title}</span>
                  <StatusPill tone={t.overdue ? "error" : "neutral"}>
                    {new Date(t.dueDate).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                    })}
                  </StatusPill>
                  <form action={deleteLeadTask}>
                    <input type="hidden" name="taskId" value={t.id} />
                    <input type="hidden" name="redirectTo" value={redirectTo} />
                    <button
                      type="submit"
                      aria-label="Delete task"
                      className="text-on-surface-variant hover:text-error"
                    >
                      ✕
                    </button>
                  </form>
                </div>
              ))}
            </div>

            <form action={addLeadTask} className="mt-3 flex flex-col gap-2">
              <input type="hidden" name="leadId" value={lead.id} />
              <input type="hidden" name="redirectTo" value={redirectTo} />
              <input
                type="text"
                name="title"
                required
                placeholder="e.g. Call back Thursday"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
              <div className="flex gap-2">
                <input
                  type="date"
                  name="dueDate"
                  required
                  className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                />
                <button
                  type="submit"
                  className="bg-primary px-3 py-2 font-mono-data text-[10px] uppercase tracking-wider text-on-primary hover:brightness-110"
                >
                  Add
                </button>
              </div>
            </form>
          </div>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Activity</CardTitle>
          <CardDescription>Notes, calls, emails, meetings, and stage changes.</CardDescription>

          <form action={addLeadNote} className="mt-4 space-y-2 border-b border-outline-variant pb-4">
            <input type="hidden" name="leadId" value={lead.id} />
            {search.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {search.error}
              </div>
            )}
            <div className="flex gap-2">
              <select
                name="kind"
                defaultValue="note"
                className="border border-outline-variant bg-background px-2 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="note">Note</option>
                <option value="call">Call</option>
                <option value="email">Email</option>
                <option value="meeting">Meeting</option>
              </select>
              <textarea
                name="content"
                required
                rows={2}
                placeholder="What happened?"
                className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary hover:brightness-110"
            >
              Log activity
            </button>
          </form>

          <div className="mt-4 max-h-[520px] space-y-4 overflow-auto">
            {activities.length === 0 && (
              <p className="py-6 text-center text-[13px] text-on-surface-variant">
                No activity logged yet.
              </p>
            )}
            {activities.map((a) => (
              <div key={a.id} className="border-l-2 border-outline-variant pl-3">
                <div className="flex items-center gap-2">
                  <StatusPill tone={a.kind === "stage_change" ? "primary" : "neutral"}>
                    {ACTIVITY_LABEL[a.kind] ?? a.kind}
                  </StatusPill>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                    {new Date(a.createdAt).toLocaleString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                  {a.createdByName && (
                    <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                      · {a.createdByName}
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[13px] text-on-surface">{a.content}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "17/18 -- Writing src/app/projects/actions.ts..."
cat > 'src/app/projects/actions.ts' << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { confirmPasswordOrRedirect } from "@/lib/auth-confirm";
import { recordActivity } from "@/lib/audit";

const VALID_STATUSES = ["on_track", "at_risk", "delayed", "completed"];

export async function addProject(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const clientName = String(formData.get("clientName") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!name) redirect("/projects?error=Please enter a project name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("projects")
    .insert({ name, client_name: clientName, notes, status: "on_track", created_by: user?.id ?? null })
    .select("id")
    .single();

  if (error) redirect(`/projects?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "projects",
    entityId: inserted?.id ?? null,
    summary: `Project "${name}" added`,
    notify: false,
  });

  revalidatePath("/projects");
  redirect("/projects");
}

export async function updateProjectStatus(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!projectId || !VALID_STATUSES.includes(status)) {
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
  if (error) redirect(`/projects?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" status → ${status}`,
    notify: false,
  });

  revalidatePath("/projects");
  redirect("/projects");
}

export async function deleteProject(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/projects";

  if (!projectId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing project id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();
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
  redirect(redirectTo);
}
SANESTIX_EOF

echo "18/18 -- Writing src/app/projects/page.tsx..."
cat > 'src/app/projects/page.tsx' << 'SANESTIX_EOF'
import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getProjects } from "@/lib/supabase/queries";
import { addProject, updateProjectStatus, deleteProject } from "@/app/projects/actions";
import type { ProjectRowStatus } from "@/lib/types";

export const dynamic = "force-dynamic";

const STATUS_OPTIONS: { value: ProjectRowStatus; label: string }[] = [
  { value: "on_track", label: "On Track" },
  { value: "at_risk", label: "At Risk" },
  { value: "delayed", label: "Delayed" },
  { value: "completed", label: "Completed" },
];

const STATUS_TONE: Record<ProjectRowStatus, "success" | "warning" | "error" | "neutral"> = {
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
  const projects = await getProjects();
  const activeCount = projects.filter((p) => p.status !== "completed").length;
  const atRiskCount = projects.filter((p) => p.status === "at_risk" || p.status === "delayed").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Projects"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Projects</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client delivery work. Projects marked with a source lead were auto-created when that
          lead was won in CRM.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
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
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a project</CardTitle>
          <CardDescription>Manually start a project not tied to a CRM lead.</CardDescription>

          <form action={addProject} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Project name
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
                Client name
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
                Notes
              </label>
              <textarea
                name="notes"
                rows={3}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add project
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Project List</CardTitle>
          <CardDescription>All projects, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Client / Company</th>
                  <th className="pb-2 pr-4">Source</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No projects yet. Add one above, or win a lead in CRM.
                    </td>
                  </tr>
                )}
                {projects.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{p.name}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.clientName ?? p.companyName ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.sourceLeadId ? (
                        <Link
                          href={`/crm/leads/${p.sourceLeadId}`}
                          className="text-primary hover:underline"
                        >
                          {p.sourceLeadTitle ?? "CRM lead"}
                        </Link>
                      ) : (
                        "Manual"
                      )}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="projectId"
                        idValue={p.id}
                        status={p.status}
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

echo ""
echo "All files written. Installing deps + building..."
npm install
npm run build
echo ""
echo "Build OK. Next steps:"
echo "  1. In the Supabase SQL editor, run supabase/schema-phase5-crm-and-projects.sql"
echo "     (safe to re-run; only needs to be run once)."
echo "  2. Redeploy: ./deploy.sh  (or: docker compose build && docker compose up -d)"
echo "  3. Visit /crm -- add a company, a lead, drag it to Won, check /projects."
