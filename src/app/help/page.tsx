import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";

export const dynamic = "force-dynamic";

export default function HelpPage() {
  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Help"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Help</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Practical guide for using the dashboard without mixing accounting categories.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-6">
          <CardTitle>Finance Rules</CardTitle>
          <CardDescription>How entries should be recorded.</CardDescription>
          <div className="mt-4 space-y-3 text-[13px] text-on-surface">
            <p>Client money and commissions go in Income.</p>
            <p>Company purchases go in Expenses.</p>
            <p>Founder-paid company costs go in Founder Investments first, then Reimbursements when paid back.</p>
            <p>Profit sharing and charity belong in Profit Split, not the normal expense ledger.</p>
          </div>
        </Card>

        <Card className="p-6">
          <CardTitle>Fast Actions</CardTitle>
          <CardDescription>Common workflows.</CardDescription>
          <div className="mt-4 flex flex-wrap gap-3">
            <Link className="border border-outline-variant px-4 py-2 text-[12px] hover:border-primary" href="/finance/transactions">
              Add income or expense
            </Link>
            <Link className="border border-outline-variant px-4 py-2 text-[12px] hover:border-primary" href="/finance/loans">
              Add founder entry
            </Link>
            <Link className="border border-outline-variant px-4 py-2 text-[12px] hover:border-primary" href="/finance/reports">
              View reports
            </Link>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
