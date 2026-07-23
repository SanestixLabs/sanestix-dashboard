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
          <TransactionTable transactions={income} emptyLabel="No income entries yet." />
        </div>
      </Card>
    </DashboardShell>
  );
}
