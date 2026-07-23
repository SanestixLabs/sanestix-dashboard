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
} from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function FinanceReportsPage() {
  const [transactions, invoices, balances, distributions] = await Promise.all([
    getTransactions(),
    getInvoices(),
    getLoanBalances(),
    getProfitDistributions(),
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
      </div>
    </DashboardShell>
  );
}
