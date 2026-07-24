import { createClient } from "@/lib/supabase/server";
import { formatCurrency } from "@/lib/utils";
import type {
  Asset,
  CashFlowPoint,
  Debt,
  Employee,
  Founder,
  Invoice,
  KpiCard,
  LoanBalance,
  LoanEntry,
  ProfitDistribution,
  RevenuePoint,
  Subscription,
  Transaction,
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
      "id, full_name, role, salary, start_date, status, notes, created_at, profiles(full_name)"
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
      notes: row.notes,
      createdByName: profile?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}
