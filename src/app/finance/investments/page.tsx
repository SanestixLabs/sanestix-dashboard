import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { LoanTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getLoanBalances, getLoanLedger } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function InvestmentsPage() {
  const [balances, ledger] = await Promise.all([getLoanBalances(), getLoanLedger()]);
  const investments = ledger.filter((entry) => entry.direction === "loan_in");
  const totalInvested = balances.reduce((sum, balance) => sum + balance.totalLoaned, 0);
  const outstanding = balances.reduce((sum, balance) => sum + balance.outstanding, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Founder Investments"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
            Founder Investments
          </h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Capital paid by founders into the company, tracked separately from income.
          </p>
        </div>
        <Link
          href="/finance/loans"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add investment
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total invested
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-warning">
            {formatCurrency(totalInvested)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Outstanding payable
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-error">
            {formatCurrency(outstanding)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Founder accounts
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{balances.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Investment Ledger</CardTitle>
        <CardDescription>Founder capital entries, newest first.</CardDescription>
        <div className="mt-4">
          <LoanTable entries={investments} emptyLabel="No founder investments yet." />
        </div>
      </Card>
    </DashboardShell>
  );
}
