#!/usr/bin/env bash
# Sanestix Finance fixes — run from the ROOT of your repo on the VPS
set -e

mkdir -p src/app/finance docs src/app/api/export/finance

echo "Writing new files..."
cat > src/app/error.tsx << 'SANESTIX_EOF'
"use client";

import { useEffect } from "react";
import { RefreshCw, AlertTriangle } from "lucide-react";

export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Unhandled app error:", error);
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-md border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-error">
          <AlertTriangle size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">Something went wrong</h1>
        </div>
        <p className="mt-2 text-[13px] text-on-surface-variant">
          {error.message || "An unexpected error occurred while loading this page."}
        </p>
        {error.digest && (
          <p className="mt-2 font-mono-data text-[11px] text-on-surface-variant/70">
            Error ref: {error.digest}
          </p>
        )}
        <button
          onClick={reset}
          className="mt-4 inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
        >
          <RefreshCw size={14} />
          Try again
        </button>
      </div>
    </div>
  );
}
SANESTIX_EOF

cat > src/app/finance/error.tsx << 'SANESTIX_EOF'
"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { RefreshCw, AlertTriangle, ArrowLeft } from "lucide-react";

export default function FinanceError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Finance module error:", error);
  }, [error]);

  const hint = useMemo(() => {
    const message = error.message ?? "";

    if (/relation .* does not exist/i.test(message) || /does not exist/i.test(message)) {
      return "This table hasn't been created in Supabase yet. Run supabase/schema.sql and supabase/schema-phase2-registers.sql (in that order) in the Supabase SQL editor, then reload.";
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
          <h1 className="text-[15px] font-semibold tracking-tight">This finance page couldn&apos;t load</h1>
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
            href="/finance"
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <ArrowLeft size={14} />
            Back to Overview
          </Link>
        </div>
      </div>
    </div>
  );
}
SANESTIX_EOF

cat > src/app/finance/loading.tsx << 'SANESTIX_EOF'
export default function FinanceLoading() {
  return (
    <div className="animate-pulse space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">
      <div className="h-7 w-56 rounded-[2px] bg-surface-container-high" />
      <div className="h-4 w-80 rounded-[2px] bg-surface-container-high" />
      <div className="h-9 w-full rounded-[2px] bg-surface-container-high" />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-24 rounded-[2px] border border-outline-variant bg-surface" />
        ))}
      </div>
      <div className="h-72 rounded-[2px] border border-outline-variant bg-surface" />
    </div>
  );
}
SANESTIX_EOF

cat > docs/FINANCE.md << 'SANESTIX_EOF'
# Finance Module — Reference

The Finance tab is the most complete module in Sanestix OS: 15 pages, all
backed by real Supabase Postgres tables (no mock data). This doc explains
what each page does, which table/action it depends on, and the most common
reason a page fails to load.

## Required setup (do this first)

Two SQL files must be run, **in this order**, in the Supabase SQL editor:

1. `supabase/schema.sql` — creates `profiles`, `finance_transactions`,
   `invoices`, `founder_loans`, `profit_distributions`.
2. `supabase/schema-phase2-registers.sql` — creates `vendors`,
   `subscriptions`, `assets`, `debts`, `employees`.

**If step 2 is skipped, the Vendors / Employees / Subscriptions / Assets /
Debts pages will fail to load.** This is the single most common cause of
"the page won't open" — the query throws `relation "public.X" does not
exist`, and (as of this update) that now surfaces as a readable error card
instead of a blank/crashed page. See `src/app/finance/error.tsx`.

Both files are idempotent (`create table if not exists`), so re-running
them is always safe.

## Error handling

- `src/app/error.tsx` — app-wide fallback for any unhandled error.
- `src/app/finance/error.tsx` — Finance-specific error boundary. Reads the
  thrown error message and shows a targeted hint:
  - `relation ... does not exist` → run the missing schema file.
  - permission denied / RLS → check the table's Row Level Security policy.
  - fetch failed / network → check `.env` Supabase URL/key.
- `src/app/finance/loading.tsx` — skeleton shown while a page's server
  component is fetching (all Finance pages are `force-dynamic`, so this
  fires on every navigation).

## Pages

| Tab | Route | Reads | Writes (Server Action) |
|---|---|---|---|
| Overview | `/finance` | `getFinanceData()` (aggregates transactions + invoices) | — |
| Income | `/finance/income` | `getTransactions()` filtered `kind = "revenue"` | `addTransaction` (finance/transactions) |
| Expenses | `/finance/expenses` | `getTransactions()` filtered `kind = "expense"` | `addTransaction` |
| Transactions | `/finance/transactions` | `getTransactions()` | `addTransaction` |
| Invoices | `/finance/invoices` | `getInvoices()` | `addInvoice`, `updateInvoiceStatus` |
| Investments | `/finance/investments` | `getLoanLedger()` filtered `direction = "loan_in"`, `getLoanBalances()` | `addLoanEntry` (finance/loans) |
| Reimbursements | `/finance/reimbursements` | `getLoanLedger()` filtered `direction = "repayment_out"`, `getLoanBalances()` | `addLoanEntry` |
| Founder Entry | `/finance/loans` | `getLoanLedger()`, `getLoanBalances()`, `getFounders()` | `addLoanEntry` |
| Profit Split | `/finance/profit-split` | `getProfitDistributions()` | `addProfitDistribution` |
| Reports | `/finance/reports` | All of the above **plus** `getVendors`, `getSubscriptions`, `getAssets`, `getDebts`, `getEmployees` | — (read-only; links to CSV export) |
| Vendors | `/finance/vendors` | `getVendors()` | `addVendor`, `updateVendorStatus` |
| Employees | `/finance/employees` | `getEmployees()` | `addEmployee`, `updateEmployeeStatus` |
| Subscriptions | `/finance/subscriptions` | `getSubscriptions()` | `addSubscription`, `updateSubscriptionStatus` |
| Assets | `/finance/assets` | `getAssets()` | `addAsset`, `updateAssetCondition` |
| Debts | `/finance/debts` | `getDebts()` | `addDebt`, `updateDebtStatus` |

All query functions live in `src/lib/supabase/queries.ts`; all mutating
actions live in `src/app/finance/actions.ts` (all `"use server"`).

### Reports page — company-wide summary

`/finance/reports` is the one page that ties every register together. It
now surfaces (in addition to the original cash/invoice/founder figures):

- **Monthly burn** — active subscriptions (annual costs amortized ÷ 12) +
  active employee salaries.
- **Asset book value** — sum of non-disposed asset purchase costs.
- **Outstanding debts** — sum of `remainingBalance` for debts not marked
  `paid`.
- **Active vendors** — count of vendors with `status = "active"`.
- **Net position** — `income − expenses + assetBookValue −
  founderPayable − outstandingDebts`. A rough net-worth figure; it does
  not account for accrued-but-unpaid subscriptions/payroll.
- **Company Registers** panel — live counts across all five Phase 2
  registers.

### CSV export

`GET /api/export/finance` streams a single CSV combining Transactions,
Invoices, Founder Loans, Profit Distributions, Vendors, Subscriptions,
Assets, Debts, and Employees (one `Section` column identifies the source).
Wrapped in try/catch — a failed query now returns a JSON `{ error }` body
with HTTP 500 instead of an unhandled server exception.

## Data model quick reference

- **Transactions** (`finance_transactions`): `kind` (`revenue` | `expense`),
  `category`, `amount`, `occurred_on`, `note`.
- **Invoices**: `client_name`, `amount`, `status` (`outstanding` | `paid` |
  `overdue`), `due_date`.
- **Founder loans** (`founder_loans`): `founder_id`, `direction`
  (`loan_in` | `repayment_out`), `amount`, `occurred_on`, `description`.
  Investments and Reimbursements are both views over this one table,
  filtered by `direction`.
- **Profit distributions**: `period_month`, `gross_profit`,
  `capital_reserve`, `loan_repayment`, `charity_pct` → derives
  `distributable_profit`, `charity_amount`, `per_founder_amount` (split
  evenly three ways).
- **Vendors**: `name`, `category`, `contact_person`, `contact_email`,
  `payment_terms`, `status` (`active` | `inactive`).
- **Subscriptions**: `vendor_name`, `cost`, `billing_cycle` (`monthly` |
  `annual`), `renewal_date`, `owner`, `status` (`active` | `cancelled`).
- **Assets**: `name`, `purchase_date`, `cost`, `owner`, `condition` (`new` |
  `good` | `fair` | `poor` | `disposed`), `serial_number`.
- **Debts**: `counterparty`, `principal`, `paid_amount` → derives
  `remaining_balance`, `due_date`, `status` (`outstanding` | `paid` |
  `overdue`).
- **Employees**: `full_name`, `role`, `salary`, `start_date`, `status`
  (`active` | `inactive`).

## Troubleshooting checklist

If a Finance page won't open:

1. Read the error card — it now tells you the actual Supabase error
   message plus a targeted hint.
2. `relation "public.X" does not exist` → you haven't run
   `schema-phase2-registers.sql` (or `schema.sql`) yet. Run it.
3. Empty page / no rows but no error → RLS is fine, table is just empty.
   Check "empty" is genuinely correct (query the table directly in the
   Supabase SQL editor).
4. `permission denied for relation X` → RLS policy doesn't grant the
   `authenticated` role access. Compare against the working tables in
   `schema.sql` for the expected policy pattern.
5. Everything 500s / nothing loads at all → check
   `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env`
   (or the VPS's `docker-compose` build args — these are baked in at
   `docker compose build` time, so a `.env` edit needs a rebuild, not just
   a restart).
SANESTIX_EOF

echo "Overwriting edited files..."
cat > src/app/finance/reports/page.tsx << 'SANESTIX_EOF'
import Link from "next/link";
import { Download } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils";
import {
  getInvoices,
  getLoanBalances,
  getProfitDistributions,
  getTransactions,
  getVendors,
  getSubscriptions,
  getAssets,
  getDebts,
  getEmployees,
} from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function FinanceReportsPage() {
  const [transactions, invoices, balances, distributions, vendors, subscriptions, assets, debts, employees] =
    await Promise.all([
      getTransactions(),
      getInvoices(),
      getLoanBalances(),
      getProfitDistributions(),
      getVendors(),
      getSubscriptions(),
      getAssets(),
      getDebts(),
      getEmployees(),
    ]);

  const income = transactions
    .filter((transaction) => transaction.kind === "revenue")
    .reduce((sum, transaction) => sum + transaction.amount, 0);
  const expenses = transactions
    .filter((transaction) => transaction.kind === "expense")
    .reduce((sum, transaction) => sum + transaction.amount, 0);
  const outstandingFounderPayable = balances.reduce((sum, balance) => sum + balance.outstanding, 0);
  const outstandingInvoices = invoices
    .filter((invoice) => invoice.status !== "paid")
    .reduce((sum, invoice) => sum + invoice.amount, 0);
  const charity = distributions.reduce((sum, distribution) => sum + distribution.charityAmount, 0);

  // Recurring monthly burn from active subscriptions (annual costs amortized).
  const activeSubscriptions = subscriptions.filter((s) => s.status === "active");
  const subscriptionMonthlyBurn = activeSubscriptions.reduce(
    (sum, s) => sum + (s.billingCycle === "annual" ? s.cost / 12 : s.cost),
    0
  );

  // Monthly payroll from active employees.
  const activeEmployees = employees.filter((e) => e.status === "active");
  const monthlyPayroll = activeEmployees.reduce((sum, e) => sum + (e.salary ?? 0), 0);

  const totalMonthlyBurn = subscriptionMonthlyBurn + monthlyPayroll;

  // Asset book value (disposed assets excluded from current net worth).
  const assetBookValue = assets
    .filter((a) => a.condition !== "disposed")
    .reduce((sum, a) => sum + a.cost, 0);

  // Outstanding debts owed to third parties (not yet paid).
  const outstandingDebts = debts
    .filter((d) => d.status !== "paid")
    .reduce((sum, d) => sum + d.remainingBalance, 0);

  const activeVendorCount = vendors.filter((v) => v.status === "active").length;

  // Net position: what the company owns minus what it owes (founders + vendors + debts).
  const netPosition = income - expenses + assetBookValue - outstandingFounderPayable - outstandingDebts;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Reports"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
            Financial Reports
          </h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Audit-ready summary of income, expenses, invoices, founder balances, and distributions.
          </p>
        </div>
        <Link
          href="/api/export/finance"
          className="inline-flex w-fit items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
        >
          <Download size={14} />
          Export CSV
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
        {[
          ["Cash received", income, "text-success"],
          ["Company expenses", expenses, "text-error"],
          ["Net operating cash", income - expenses, income - expenses >= 0 ? "text-success" : "text-error"],
          ["Founder payable", outstandingFounderPayable, "text-warning"],
          ["Open invoices", outstandingInvoices, "text-warning"],
        ].map(([label, value, tone]) => (
          <Card key={String(label)} className="p-4">
            <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
              {label}
            </p>
            <p className={`mt-2 text-[22px] font-bold tracking-tight ${tone}`}>
              {formatCurrency(Number(value))}
            </p>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
        {[
          ["Monthly burn (subs + payroll)", totalMonthlyBurn, "text-error"],
          ["Asset book value", assetBookValue, "text-success"],
          ["Outstanding debts", outstandingDebts, "text-warning"],
          ["Active vendors", activeVendorCount, "text-on-surface", true],
          ["Net position", netPosition, netPosition >= 0 ? "text-success" : "text-error"],
        ].map(([label, value, tone, isCount]) => (
          <Card key={String(label)} className="p-4">
            <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
              {label}
            </p>
            <p className={`mt-2 text-[22px] font-bold tracking-tight ${tone}`}>
              {isCount ? Number(value) : formatCurrency(Number(value))}
            </p>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-6">
          <CardTitle>Founder Account Summary</CardTitle>
          <CardDescription>Invested, returned, and outstanding per founder.</CardDescription>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[520px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Founder</th>
                  <th className="pb-2 pr-4 text-right">Invested</th>
                  <th className="pb-2 pr-4 text-right">Returned</th>
                  <th className="pb-2 text-right">Outstanding</th>
                </tr>
              </thead>
              <tbody>
                {balances.map((balance) => (
                  <tr key={balance.founderId} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4">{balance.founderName ?? "-"}</td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(balance.totalLoaned)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(balance.totalRepaid)}
                    </td>
                    <td className="py-2.5 text-right font-mono-data text-warning">
                      {formatCurrency(balance.outstanding)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>

        <Card className="p-6">
          <CardTitle>Distribution Summary</CardTitle>
          <CardDescription>Profit waterfall history and charity tracking.</CardDescription>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Distribution runs</span>
              <span className="font-mono-data">{distributions.length}</span>
            </div>
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Charity recorded</span>
              <span className="font-mono-data text-success">{formatCurrency(charity)}</span>
            </div>
            <div className="flex justify-between border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Transactions recorded</span>
              <span className="font-mono-data">{transactions.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-on-surface-variant">Invoices recorded</span>
              <span className="font-mono-data">{invoices.length}</span>
            </div>
          </div>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Company Registers</CardTitle>
          <CardDescription>Live counts across the Phase 2 operational registers.</CardDescription>
          <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-5">
            {[
              ["Vendors", vendors.length],
              ["Subscriptions", activeSubscriptions.length],
              ["Assets", assets.filter((a) => a.condition !== "disposed").length],
              ["Open debts", debts.filter((d) => d.status !== "paid").length],
              ["Employees", activeEmployees.length],
            ].map(([label, value]) => (
              <div key={String(label)} className="border-l-2 border-outline-variant pl-3">
                <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  {label}
                </p>
                <p className="mt-1 text-[18px] font-bold tracking-tight text-on-surface">{value}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
SANESTIX_EOF

cat > src/app/api/export/finance/route.ts << 'SANESTIX_EOF'
import {
  getInvoices,
  getLoanLedger,
  getProfitDistributions,
  getTransactions,
  getVendors,
  getSubscriptions,
  getAssets,
  getDebts,
  getEmployees,
} from "@/lib/supabase/queries";

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
    const [transactions, invoices, loans, distributions, vendors, subscriptions, assets, debts, employees] =
      await Promise.all([
        getTransactions(),
        getInvoices(),
        getLoanLedger(),
        getProfitDistributions(),
        getVendors(),
        getSubscriptions(),
        getAssets(),
        getDebts(),
        getEmployees(),
      ]);

    const rows = [
      csvRow(["Section", "Date", "Type", "Name", "Category/Status", "Description", "Amount PKR"]),
      ...transactions.map((transaction) =>
        csvRow([
          "Transactions",
          transaction.occurredOn,
          transaction.kind,
          transaction.category,
          "",
          transaction.note,
          transaction.amount,
        ])
      ),
      ...invoices.map((invoice) =>
        csvRow([
          "Invoices",
          invoice.dueDate,
          "invoice",
          invoice.clientName,
          invoice.status,
          invoice.createdByName,
          invoice.amount,
        ])
      ),
      ...loans.map((entry) =>
        csvRow([
          "Founder Loans",
          entry.occurredOn,
          entry.direction,
          entry.founderName,
          "",
          entry.description,
          entry.amount,
        ])
      ),
      ...distributions.map((distribution) =>
        csvRow([
          "Profit Distributions",
          distribution.periodMonth,
          "distribution",
          "Sanestix",
          `charity ${distribution.charityPct}%`,
          distribution.note,
          distribution.distributableProfit,
        ])
      ),
      ...vendors.map((vendor) =>
        csvRow(["Vendors", vendor.createdAt, "vendor", vendor.name, vendor.status, vendor.notes, ""])
      ),
      ...subscriptions.map((subscription) =>
        csvRow([
          "Subscriptions",
          subscription.renewalDate,
          subscription.billingCycle,
          subscription.vendorName,
          subscription.status,
          subscription.notes,
          subscription.cost,
        ])
      ),
      ...assets.map((asset) =>
        csvRow([
          "Assets",
          asset.purchaseDate,
          "asset",
          asset.name,
          asset.condition,
          asset.notes,
          asset.cost,
        ])
      ),
      ...debts.map((debt) =>
        csvRow([
          "Debts",
          debt.dueDate,
          "debt",
          debt.counterparty,
          debt.status,
          debt.notes,
          debt.remainingBalance,
        ])
      ),
      ...employees.map((employee) =>
        csvRow([
          "Employees",
          employee.startDate,
          "employee",
          employee.fullName,
          employee.status,
          employee.role,
          employee.salary ?? "",
        ])
      ),
    ];

    return new Response(rows.join("\n"), {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="sanestix-finance-export.csv"',
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
SANESTIX_EOF

cat > README.md << 'SANESTIX_EOF'
# Sanestix OS — Executive Dashboard

This is the first real screen of Sanestix OS, built from the locked Phase 0
design system (Stitch export: monochrome "Linear Minimalism" + cyan accent)
and the Phase 1.5 spec in `Sanestix-OS-Roadmap.md`:

> KPI cards pulling from Finance + Projects + CRM. 3–4 charts max at launch
> (Revenue Trend, Cash Flow, Sales Funnel, Project Progress).

It's a real, deployable Next.js app — not a static mockup. Data is mocked
today in a shape that mirrors what the FastAPI backend should return once
Phase 1.2–1.4 (Finance, Projects, CRM) ship, so wiring it up later is a
one-file change (see `src/lib/data.ts`).

## Stack

- **Next.js 16** (App Router, React Server Components)
- **TypeScript**
- **Tailwind CSS v4** — design tokens defined in `src/app/globals.css` as CSS
  variables (`@theme`), matching the DESIGN.md palette exactly
- **Recharts** — Revenue Trend and Cash Flow charts
- **lucide-react** — icon set

**Status:**
- **Auth** — real, via Supabase Auth (email/password). See "Auth & Database (Supabase)" below.
- **Finance** — real, backed by Supabase Postgres, across 15 pages (Overview, Income,
  Expenses, Transactions, Invoices, Investments, Reimbursements, Founder Entry,
  Profit Split, Reports, Vendors, Employees, Subscriptions, Assets, Debts). See
  `docs/FINANCE.md` for the full breakdown of every page, table, and action.
- **Projects, CRM** — still mock data in `src/lib/data.ts`, clearly labeled, per the
  roadmap's own sequencing (Auth → Finance → Projects → CRM → Dashboard).

Every route under `/finance` now has a scoped `error.tsx` (readable error card
with a likely-cause hint and a "Try again" button, instead of the raw Next.js
error screen) and a `loading.tsx` skeleton — see `src/app/finance/error.tsx`.

## Project structure

```
src/
  middleware.ts           Refreshes Supabase session, gates /login vs dashboard
  app/
    layout.tsx           Root layout, loads Inter + JetBrains Mono
    globals.css          Design tokens (colors, radius, fonts) as CSS vars
    page.tsx             The Executive Dashboard page (protected)
    login/page.tsx       Sign-in form
    signup/page.tsx      Sign-up form
    auth/actions.ts       Server actions: signIn / signUp / signOut
    finance/
      page.tsx            Overview — KPIs + revenue/cash-flow charts
      transactions/page.tsx Full transaction ledger + add-entry form
      invoices/page.tsx   Full invoice list + add-invoice form + inline status
      loans/page.tsx      Founder loan ledger + balances
      profit-split/page.tsx Profit distribution waterfall + history
      actions.ts          Server actions: addTransaction, addInvoice,
                          updateInvoiceStatus, addLoanEntry, addProfitDistribution
  components/
    layout/
      sidebar.tsx         Module switcher (Dashboard/Finance/Projects/CRM/...)
      topbar.tsx          Breadcrumb, global search, notifications
      dashboard-shell.tsx Combines sidebar + topbar + content canvas
      finance-tabs.tsx    Overview/Transactions/Invoices/Loans/Profit Split tabs
    dashboard/
      kpi-card.tsx
      revenue-trend-chart.tsx
      cash-flow-chart.tsx
      sales-funnel-chart.tsx
      project-progress-chart.tsx
      activity-feed.tsx
    finance/
      invoice-status-form.tsx Inline invoice-status dropdown (client component)
    ui/
      card.tsx
      status-pill.tsx
  lib/
    types.ts              Shared domain types (mirrors future API shapes)
    data.ts                getDashboardData() — merges real Finance data
                           with mock Projects/CRM data
    utils.ts               cn(), formatCurrency() (PKR), formatNumber()
    supabase/
      client.ts             Browser Supabase client (client components)
      server.ts              Server Supabase client (Server Components/Actions)
      queries.ts              getFinanceData(), getTransactions(), getInvoices(),
                               getFounders(), getLoanLedger(), getLoanBalances(),
                               getProfitDistributions()
scripts/
  setup-founders.mjs      Run locally: provisions the 3 founder auth accounts
                          via the Supabase Admin API (needs service_role key)
supabase/
  schema.sql              Run this once in the Supabase SQL editor
  seed-founders-finance.sql Run once, after the 3 founders exist, to seed
                          their loan ledger + profit-split history
```

## Auth & Database (Supabase)

This app uses [Supabase](https://supabase.com) for both auth and the database
— a hosted Postgres with built-in auth, so there's nothing to self-host.

### 1. Create the project

1. Go to https://supabase.com/dashboard → **New project**.
2. Pick a name (e.g. `sanestix-os`), a strong database password (save it
   somewhere — Supabase won't show it again), and a region close to your
   VPS (e.g. Frankfurt/Singapore depending on where `72.61.143.58` is).
3. Wait ~2 minutes for provisioning.

### 2. Run the schema

1. In the project, open **SQL Editor → New query**.
2. Paste the entire contents of `supabase/schema.sql` (in this repo) and
   run it. This creates:
   - `profiles` — one row per user, auto-created on signup, with a `role`
     column (`admin`/`member`) for later use
   - `finance_transactions` and `invoices` — the real tables behind the
     Finance Overview/Transactions/Invoices pages, with Row Level Security
     enabled and several months of realistic **PKR** seed data across
     multiple categories (payroll, rent, marketing, software, taxes, etc.)
     so the dashboard isn't empty on first login
   - `founder_loans` and `profit_distributions` — the tables behind the
     Loan Ledger and Profit Split pages (left empty here — see step 6 below)
3. You can re-run this file safely later — it's idempotent.

### 2b. Run the Phase 2 registers schema (required for 5 of the Finance tabs)

The **Vendors, Employees, Subscriptions, Assets, and Debts** pages read from
tables that are **not** in `schema.sql` — they live in a separate file. If
you skip this step, those 5 pages will fail to load (they'll show a "This
finance page couldn't load" error instead of data) because their tables
don't exist yet.

1. In the SQL Editor, paste the entire contents of
   `supabase/schema-phase2-registers.sql` and run it.
2. This creates `vendors`, `subscriptions`, `assets`, `debts`, and
   `employees` — all with Row Level Security enabled, same pattern as
   `schema.sql`.
3. Also idempotent — safe to re-run.

### 3. Get your API keys

**Project Settings → API** (gear icon, bottom left). You need:

- **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
- **anon / public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Both are safe to expose to the browser — Row Level Security in
`schema.sql` is what actually controls access, not secrecy of these keys.

### 4. Turn off email confirmation for now (optional, faster local testing)

**Authentication → Providers → Email** → toggle off "Confirm email" if you
want to sign up and immediately sign in without clicking a confirmation
email. Turn it back on before giving real people accounts.

### 5. Set your env vars

```bash
cp .env.example .env
# then edit .env and paste in the two values from step 3
```

### 6. Create the 3 founder accounts (optional)

The Loan Ledger and Profit Split pages need real founder accounts to attach
loans/distributions to. This app doesn't have an admin UI for that yet, so
it's done with a script that talks directly to the Supabase Admin API —
run it locally, not from the deployed app:

```bash
# also grab the service_role key from Project Settings → API and put it in
# .env as SUPABASE_SERVICE_ROLE_KEY (never commit this — it bypasses RLS)
export $(grep -v '^#' .env | xargs)
npm run setup:founders -- \
  --name "Founder One"   --email founder1@sanestix.com \
  --name "Founder Two"   --email founder2@sanestix.com \
  --name "Founder Three" --email founder3@sanestix.com
```

This creates 3 pre-confirmed auth users (no email confirmation needed),
generates a strong random password for each, and prints a credentials table
— **save those passwords immediately**, they're shown once and never stored.
The `handle_new_user` trigger from `schema.sql` fills in `profiles`
automatically for each.

Then, in the SQL Editor, run `supabase/seed-founders-finance.sql` (after
editing the `founder_names` array at the top to match the `--name` values
you used above) to seed a few months of loan-ledger and profit-split history
for these three founders.

## Run locally

```bash
npm install
cp .env.example .env   # fill in your Supabase URL + anon key
npm run dev
```

Open http://localhost:3000 — you'll be redirected to `/login`. Use
`/signup` to create your first account.

## Build for production

```bash
npm run build
npm run start
```

## Deploy — this VPS (sanestix, Traefik)

This server already runs **Traefik** as the single reverse proxy on ports
80/443 (used by `n8n`, `sanestix-flow`, and `marwaa-whatsapp`). The host's
system `nginx` is not actually in the request path for those projects and
is currently crash-looping because Traefik holds port 80 — that's a
pre-existing issue, unrelated to this deploy, and this setup doesn't touch
nginx at all.

This project follows the same pattern: **its own container, on the shared
`n8n_default` Docker network, exposed only via Traefik labels.** No host
ports are published, no other project's files or containers are touched.

**One-time DNS step (do this first, outside the VPS):** in your DNS
provider for `sanestix.com`, add:

```
Type: A
Name: dashboard
Value: 72.61.143.58
```

**On the VPS:**

```bash
# 1. Get the code onto the box, e.g.:
mkdir -p /opt/sanestix-dashboard
# copy the contents of this folder into /opt/sanestix-dashboard
# (scp, rsync, or git clone your repo there)

cd /opt/sanestix-dashboard

# 2. Create .env with your real Supabase values (this file is gitignored —
#    create it directly on the VPS, don't commit it)
cp .env.example .env
nano .env   # paste in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY

# 3. Build and start
docker compose build
docker compose up -d

# or just:
./deploy.sh
```

**Important:** the Supabase URL/key are baked into the JS bundle at
`docker compose build` time (see the Dockerfile's `ARG`s). If you ever
change `.env`, you must rebuild (`docker compose build`), not just
restart — `deploy.sh` already does this for you.

Traefik picks the new container up automatically via its Docker labels
(`docker.providers=true`) — no Traefik restart needed. It will request a
Let's Encrypt cert for `dashboard.sanestix.com` via the existing
`mytlschallenge` HTTP-challenge resolver the first time it sees traffic on
that host, using the same flow as `flow.sanestix.com`.

**Check it worked:**

```bash
docker compose ps                 # container should be "Up"
docker compose logs -f            # app logs
docker logs n8n-traefik-1 --tail 50   # confirm Traefik picked up the router
```

Then visit `https://dashboard.sanestix.com`.

**Redeploying after a code change:** re-run `./deploy.sh`, or
`docker compose up -d --build`.

**Removing it entirely:** `docker compose down` in `/opt/sanestix-dashboard`
— this only stops/removes this project's own container; nothing shared is
affected.

## Deploy — elsewhere (Vercel, other hosts)

**Vercel (zero config):** push to a GitHub repo, import at
https://vercel.com/new — Next.js is auto-detected.

**Any other Docker host:** the `Dockerfile` here is self-contained
(multi-stage, Next.js standalone output). Build and run it directly:

```bash
docker build -t sanestix-dashboard .
docker run -p 3000:3000 sanestix-dashboard
```

## Wiring in the next module (Projects or CRM)

Finance is the template. To bring Projects or CRM onto real data:

1. Design the table(s) in Supabase (SQL editor), following the pattern in
   `supabase/schema.sql` — RLS enabled, `authenticated`-role policies.
2. Add a `getProjectsData()` / `getCrmData()` function to
   `src/lib/supabase/queries.ts`, shaped to return the relevant slice of
   `DashboardData` (see `getFinanceData()` for the pattern).
3. Merge it into `getDashboardData()` in `src/lib/data.ts` the same way
   Finance is merged — replace the corresponding mock KPIs/chart data,
   keep everything else.

No component changes are required — every chart and card already reads
from the `DashboardData` shape in `src/lib/types.ts`.

## Design system notes

Colors, spacing, radius, and type scale live as CSS variables in
`src/app/globals.css` under `:root` and are exposed to Tailwind via
`@theme inline`, so utility classes like `bg-surface`, `text-on-surface-variant`,
`border-outline-variant`, and `text-primary` are available everywhere.
Corners are 2px ("sharp") across cards, buttons, and inputs, matching the
Stitch DESIGN.md spec. Fonts (Inter for UI, JetBrains Mono for
labels/data/timestamps) are loaded via a `<link>` tag rather than
`next/font`, so the build has no external dependency at build time — only
the browser needs network access to Google Fonts at runtime.

## What's deliberately not here yet

Per the roadmap's own risk list ("Dashboard-first is a trap"), this ships
with realistic mock data, not a live dashboard wired to nothing. The
roadmap's actual build order is Auth → Finance → Projects → CRM →
Dashboard — this screen is the target the other four modules build
toward, built first because Phase 0 says UI should be locked before app
code exists.
SANESTIX_EOF

echo "Done. Building..."
npm run build
