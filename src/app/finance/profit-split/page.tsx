import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils";
import { getProfitDistributions, getTotalOutstandingLoans } from "@/lib/supabase/queries";
import { addProfitDistribution } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function ProfitSplitPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [distributions, outstandingLoans] = await Promise.all([
    getProfitDistributions(),
    getTotalOutstandingLoans(),
  ]);

  const now = new Date();
  const defaultPeriod = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Profit Split"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Profit Split</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Run the monthly waterfall: gross profit → capital reserve → loan repayment →
          charity → equal 3-way founder split.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        {/* Run a new distribution */}
        <Card className="p-6">
          <CardTitle>Run a distribution</CardTitle>
          <CardDescription>
            Outstanding founder loans right now:{" "}
            <span className="font-mono-data text-on-surface">
              {formatCurrency(outstandingLoans)}
            </span>
          </CardDescription>

          <form action={addProfitDistribution} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Period (month)
              </label>
              <input
                type="month"
                name="periodMonth"
                required
                defaultValue={defaultPeriod}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Gross profit
              </label>
              <input
                type="number"
                name="grossProfit"
                step="0.01"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0.00"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Capital reserve
              </label>
              <input
                type="number"
                name="capitalReserve"
                step="0.01"
                min="0"
                defaultValue={0}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0.00"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Loan repayment
              </label>
              <input
                type="number"
                name="loanRepayment"
                step="0.01"
                min="0"
                defaultValue={outstandingLoans > 0 ? outstandingLoans.toFixed(2) : 0}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0.00"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Charity %
              </label>
              <input
                type="number"
                name="charityPct"
                step="0.1"
                min="0"
                max="100"
                defaultValue={10}
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
              Run distribution
            </button>
          </form>
        </Card>

        {/* History */}
        <Card className="p-6 lg:col-span-2">
          <CardTitle>History</CardTitle>
          <CardDescription>Past distributions, newest first.</CardDescription>

          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-left text-[13px]">
              <thead>
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Period</th>
                  <th className="pb-2 pr-4 text-right">Gross</th>
                  <th className="pb-2 pr-4 text-right">Reserve</th>
                  <th className="pb-2 pr-4 text-right">Loan repaid</th>
                  <th className="pb-2 pr-4 text-right">Charity</th>
                  <th className="pb-2 text-right">Per founder</th>
                </tr>
              </thead>
              <tbody>
                {distributions.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No distributions run yet.
                    </td>
                  </tr>
                )}
                {distributions.map((d) => (
                  <tr key={d.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {d.periodMonth.slice(0, 7)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(d.grossProfit)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-on-surface-variant">
                      {formatCurrency(d.capitalReserve)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-on-surface-variant">
                      {formatCurrency(d.loanRepayment)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-on-surface-variant">
                      {formatCurrency(d.charityAmount)}
                    </td>
                    <td className="py-2.5 text-right font-mono-data text-success">
                      {formatCurrency(d.perFounderAmount)}
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
