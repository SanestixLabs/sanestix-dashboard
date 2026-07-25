#!/usr/bin/env bash
# Sanestix Finance — add "Delete" to Transactions/Income/Expenses
# Run from the ROOT of your repo (same place you ran apply-finance-fixes.sh)
set -e

mkdir -p src/components/finance src/app/finance/transactions src/app/finance/income src/app/finance/expenses supabase

echo "1/6 — New file: delete button component..."
cat > src/components/finance/delete-transaction-button.tsx << 'SANESTIX_EOF'
"use client";

import { Trash2 } from "lucide-react";
import { deleteTransaction } from "@/app/finance/actions";

export function DeleteTransactionButton({
  transactionId,
  redirectTo,
}: {
  transactionId: string;
  redirectTo: string;
}) {
  return (
    <form
      action={deleteTransaction}
      onSubmit={(event) => {
        if (!window.confirm("Delete this transaction? This cannot be undone.")) {
          event.preventDefault();
        }
      }}
    >
      <input type="hidden" name="transactionId" value={transactionId} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <button
        type="submit"
        aria-label="Delete transaction"
        title="Delete transaction"
        className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-error-tint hover:text-error"
      >
        <Trash2 size={14} />
      </button>
    </form>
  );
}
SANESTIX_EOF

echo "2/6 — Appending deleteTransaction server action..."
cat >> src/app/finance/actions.ts << 'SANESTIX_EOF'

export async function deleteTransaction(formData: FormData) {
  const transactionId = String(formData.get("transactionId") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/finance/transactions");

  if (!transactionId) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Missing transaction id")}`);
  }

  const supabase = await createClient();
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
SANESTIX_EOF

echo "3/6 — Overwriting finance-ledger-table.tsx (adds Actions column)..."
cat > src/components/finance/finance-ledger-table.tsx << 'SANESTIX_EOF'
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import type { LoanEntry, Transaction } from "@/lib/types";
import { DeleteTransactionButton } from "@/components/finance/delete-transaction-button";

export function TransactionTable({
  transactions,
  emptyLabel,
  redirectTo = "/finance/transactions",
}: {
  transactions: Transaction[];
  emptyLabel: string;
  redirectTo?: string;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[760px] text-left text-[13px]">
        <thead>
          <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            <th className="pb-2 pr-4">Date</th>
            <th className="pb-2 pr-4">Type</th>
            <th className="pb-2 pr-4">Category</th>
            <th className="pb-2 pr-4">Description</th>
            <th className="pb-2 pr-4">Logged by</th>
            <th className="pb-2 pr-4 text-right">Amount</th>
            <th className="pb-2 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          {transactions.length === 0 && (
            <tr>
              <td colSpan={7} className="py-6 text-center text-on-surface-variant">
                {emptyLabel}
              </td>
            </tr>
          )}
          {transactions.map((transaction) => (
            <tr key={transaction.id} className="border-b border-outline-variant/50">
              <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                {transaction.occurredOn}
              </td>
              <td className="py-2.5 pr-4">
                <StatusPill tone={transaction.kind === "revenue" ? "success" : "neutral"}>
                  {transaction.kind === "revenue" ? "Income" : "Expense"}
                </StatusPill>
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.category ?? "-"}
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.note ?? "-"}
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.createdByName ?? "-"}
              </td>
              <td
                className={
                  "py-2.5 pr-4 text-right font-mono-data " +
                  (transaction.kind === "revenue" ? "text-success" : "text-error")
                }
              >
                {transaction.kind === "revenue" ? "+" : "-"}
                {formatCurrency(transaction.amount)}
              </td>
              <td className="py-2.5 text-right">
                <div className="flex justify-end">
                  <DeleteTransactionButton transactionId={transaction.id} redirectTo={redirectTo} />
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function LoanTable({
  entries,
  emptyLabel,
}: {
  entries: LoanEntry[];
  emptyLabel: string;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[720px] text-left text-[13px]">
        <thead>
          <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            <th className="pb-2 pr-4">Date</th>
            <th className="pb-2 pr-4">Founder</th>
            <th className="pb-2 pr-4">Description</th>
            <th className="pb-2 pr-4">Direction</th>
            <th className="pb-2 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 && (
            <tr>
              <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                {emptyLabel}
              </td>
            </tr>
          )}
          {entries.map((entry) => (
            <tr key={entry.id} className="border-b border-outline-variant/50">
              <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                {entry.occurredOn}
              </td>
              <td className="py-2.5 pr-4">{entry.founderName ?? "-"}</td>
              <td className="py-2.5 pr-4 text-on-surface-variant">{entry.description}</td>
              <td className="py-2.5 pr-4">
                <StatusPill tone={entry.direction === "loan_in" ? "warning" : "success"}>
                  {entry.direction === "loan_in" ? "Investment" : "Returned"}
                </StatusPill>
              </td>
              <td className="py-2.5 text-right font-mono-data">
                {formatCurrency(entry.amount)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
SANESTIX_EOF

echo "4/6 — Overwriting income/page.tsx (passes redirectTo)..."
cat > src/app/finance/income/page.tsx << 'SANESTIX_EOF'
import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { TransactionTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function IncomePage() {
  const income = (await getTransactions()).filter((transaction) => transaction.kind === "revenue");
  const total = income.reduce((sum, transaction) => sum + transaction.amount, 0);
  const sourceCount = new Set(income.map((transaction) => transaction.category ?? "uncategorized")).size;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Income"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Income</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Cash received from clients, commissions, retainers, and other company inflows.
          </p>
        </div>
        <Link
          href="/finance/transactions"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add income
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total income
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-success">
            {formatCurrency(total)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Entries
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{income.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Sources
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{sourceCount}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Income Register</CardTitle>
        <CardDescription>All recorded inflows, newest first.</CardDescription>
        <div className="mt-4">
          <TransactionTable
            transactions={income}
            emptyLabel="No income entries yet."
            redirectTo="/finance/income"
          />
        </div>
      </Card>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "5/6 — Overwriting expenses/page.tsx (passes redirectTo)..."
cat > src/app/finance/expenses/page.tsx << 'SANESTIX_EOF'
import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { TransactionTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function ExpensesPage() {
  const expenses = (await getTransactions()).filter((transaction) => transaction.kind === "expense");
  const total = expenses.reduce((sum, transaction) => sum + transaction.amount, 0);
  const paidBySaad = expenses
    .filter((transaction) => transaction.note?.toLowerCase().includes("paid by saad"))
    .reduce((sum, transaction) => sum + transaction.amount, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Expenses"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Expenses</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Company expenses separated from reimbursements and founder loan repayments.
          </p>
        </div>
        <Link
          href="/finance/transactions"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add expense
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total expenses
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-error">
            {formatCurrency(total)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Paid by Saad
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-warning">
            {formatCurrency(paidBySaad)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Entries
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{expenses.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Expense Ledger</CardTitle>
        <CardDescription>All company expenses, newest first.</CardDescription>
        <div className="mt-4">
          <TransactionTable
            transactions={expenses}
            emptyLabel="No expense entries yet."
            redirectTo="/finance/expenses"
          />
        </div>
      </Card>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "6/6 — Overwriting transactions/page.tsx (adds Actions column to inline ledger)..."
cat > src/app/finance/transactions/page.tsx << 'SANESTIX_EOF'
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";
import { addTransaction } from "@/app/finance/actions";
import { DeleteTransactionButton } from "@/components/finance/delete-transaction-button";

const CATEGORY_SUGGESTIONS = [
  "client services",
  "product sales",
  "payroll",
  "rent",
  "utilities",
  "software & tools",
  "marketing",
  "contractor",
  "taxes",
  "misc",
];

export const dynamic = "force-dynamic";

export default async function TransactionsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const transactions = await getTransactions();

  const today = new Date().toISOString().slice(0, 10);
  const totalRevenue = transactions
    .filter((t) => t.kind === "revenue")
    .reduce((sum, t) => sum + t.amount, 0);
  const totalExpenses = transactions
    .filter((t) => t.kind === "expense")
    .reduce((sum, t) => sum + t.amount, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Transactions"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Transactions</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Every revenue and expense entry behind the Overview KPIs, in PKR.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total revenue (all time)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(totalRevenue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total expenses (all time)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {formatCurrency(totalExpenses)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Net (all time)
          </p>
          <p
            className={
              "mt-2 text-[22px] font-bold tracking-tight " +
              (totalRevenue - totalExpenses >= 0 ? "text-success" : "text-error")
            }
          >
            {formatCurrency(totalRevenue - totalExpenses)}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Log an entry</CardTitle>
          <CardDescription>Record a new revenue or expense transaction.</CardDescription>

          <form action={addTransaction} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Kind
              </label>
              <select
                name="kind"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="revenue">Revenue</option>
                <option value="expense">Expense</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Category
              </label>
              <input
                type="text"
                name="category"
                list="category-suggestions"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. payroll"
              />
              <datalist id="category-suggestions">
                {CATEGORY_SUGGESTIONS.map((c) => (
                  <option key={c} value={c} />
                ))}
              </datalist>
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
                Date
              </label>
              <input
                type="date"
                name="occurredOn"
                required
                defaultValue={today}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Note
              </label>
              <input
                type="text"
                name="note"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add entry
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Ledger</CardTitle>
          <CardDescription>All transactions, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Date</th>
                  <th className="pb-2 pr-4">Kind</th>
                  <th className="pb-2 pr-4">Category</th>
                  <th className="pb-2 pr-4">Note</th>
                  <th className="pb-2 pr-4">Logged by</th>
                  <th className="pb-2 pr-4 text-right">Amount</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {transactions.length === 0 && (
                  <tr>
                    <td colSpan={7} className="py-6 text-center text-on-surface-variant">
                      No transactions yet.
                    </td>
                  </tr>
                )}
                {transactions.map((t) => (
                  <tr key={t.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {t.occurredOn}
                    </td>
                    <td className="py-2.5 pr-4">
                      <StatusPill tone={t.kind === "revenue" ? "success" : "neutral"}>
                        {t.kind === "revenue" ? "Revenue" : "Expense"}
                      </StatusPill>
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{t.category ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{t.note ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {t.createdByName ?? "—"}
                    </td>
                    <td
                      className={
                        "py-2.5 pr-4 text-right font-mono-data " +
                        (t.kind === "revenue" ? "text-success" : "text-error")
                      }
                    >
                      {t.kind === "revenue" ? "+" : "-"}
                      {formatCurrency(t.amount)}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <DeleteTransactionButton
                          transactionId={t.id}
                          redirectTo="/finance/transactions"
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

echo "Appending DELETE row-level-security policy to supabase/schema.sql..."
cat >> supabase/schema.sql << 'SANESTIX_EOF'

-- ---------------------------------------------------------------------------
-- Delete support for the Finance Transactions/Income/Expenses "Delete" button.
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated users can delete transactions" on public.finance_transactions;
create policy "Authenticated users can delete transactions"
  on public.finance_transactions for delete to authenticated using (true);
SANESTIX_EOF

echo "Done. Building..."
npm run build
