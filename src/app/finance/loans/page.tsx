import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import { getFounders, getLoanBalances, getLoanLedger } from "@/lib/supabase/queries";
import { addLoanEntry } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function LoanLedgerPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [founders, balances, ledger] = await Promise.all([
    getFounders(),
    getLoanBalances(),
    getLoanLedger(),
  ]);

  const today = new Date().toISOString().slice(0, 10);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Loan Ledger"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Loan Ledger</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Money founders have put in as a loan, and what&apos;s been paid back.
        </p>
      </div>

      <FinanceTabs />

      {/* Outstanding balances per founder */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        {balances.length === 0 && (
          <Card className="p-6 text-[13px] text-on-surface-variant md:col-span-3">
            No founders yet — sign up the other co-founders so balances show up here.
          </Card>
        )}
        {balances.map((b) => (
          <Card key={b.founderId} className="p-4">
            <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
              {b.founderName ?? "Unnamed founder"}
            </p>
            <p
              className={
                "mt-2 text-[24px] font-bold tracking-tight " +
                (b.outstanding > 0 ? "text-warning" : "text-success")
              }
            >
              {formatCurrency(b.outstanding)}
            </p>
            <p className="mt-1 text-[11px] text-on-surface-variant">
              {formatCurrency(b.totalLoaned)} loaned · {formatCurrency(b.totalRepaid)} repaid
            </p>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        {/* Add entry form */}
        <Card className="p-6">
          <CardTitle>Log an entry</CardTitle>
          <CardDescription>Record a new loan-in or a repayment-out.</CardDescription>

          <form action={addLoanEntry} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Founder
              </label>
              <select
                name="founderId"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="" disabled>
                  Select founder
                </option>
                {founders.map((f) => (
                  <option key={f.id} value={f.id}>
                    {f.fullName ?? f.id}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Direction
              </label>
              <select
                name="direction"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="loan_in">Loan in (founder → company)</option>
                <option value="repayment_out">Repayment out (company → founder)</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Amount
              </label>
              <input
                type="number"
                name="amount"
                step="0.01"
                min="0.01"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0.00"
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
                Description
              </label>
              <input
                type="text"
                name="description"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Covered July payroll shortfall"
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

        {/* Ledger table */}
        <Card className="p-6 lg:col-span-2">
          <CardTitle>Ledger</CardTitle>
          <CardDescription>All loan and repayment entries, newest first.</CardDescription>

          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-left text-[13px]">
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
                {ledger.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No entries yet.
                    </td>
                  </tr>
                )}
                {ledger.map((entry) => (
                  <tr key={entry.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {entry.occurredOn}
                    </td>
                    <td className="py-2.5 pr-4">{entry.founderName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{entry.description}</td>
                    <td className="py-2.5 pr-4">
                      <StatusPill tone={entry.direction === "loan_in" ? "warning" : "success"}>
                        {entry.direction === "loan_in" ? "Loan in" : "Repayment out"}
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
        </Card>
      </div>
    </DashboardShell>
  );
}
