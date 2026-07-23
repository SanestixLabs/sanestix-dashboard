import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { LoanTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getLoanBalances, getLoanLedger } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function ReimbursementsPage() {
  const [balances, ledger] = await Promise.all([getLoanBalances(), getLoanLedger()]);
  const reimbursements = ledger.filter((entry) => entry.direction === "repayment_out");
  const totalReturned = balances.reduce((sum, balance) => sum + balance.totalRepaid, 0);
  const outstanding = balances.reduce((sum, balance) => sum + balance.outstanding, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Reimbursements"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
            Reimbursements
          </h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Founder repayments and reimbursed company costs, separated from normal expenses.
          </p>
        </div>
        <Link
          href="/finance/loans"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add repayment
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total returned
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-success">
            {formatCurrency(totalReturned)}
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
            Repayment entries
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{reimbursements.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Loan & Reimbursement Ledger</CardTitle>
        <CardDescription>Repayments and reimbursements, newest first.</CardDescription>
        <div className="mt-4">
          <LoanTable entries={reimbursements} emptyLabel="No reimbursements yet." />
        </div>
      </Card>
    </DashboardShell>
  );
}
