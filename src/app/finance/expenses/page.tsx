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
          <TransactionTable transactions={expenses} emptyLabel="No expense entries yet." />
        </div>
      </Card>
    </DashboardShell>
  );
}
