import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { formatCurrency } from "@/lib/utils";
import { getDebts } from "@/lib/supabase/queries";
import { addDebt, updateDebtStatus } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function DebtsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const debts = await getDebts();
  const totalOutstanding = debts
    .filter((d) => d.status !== "paid")
    .reduce((sum, d) => sum + d.remainingBalance, 0);
  const overdueCount = debts.filter((d) => d.status === "overdue").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Debts & Liabilities"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">
          Debts & Liabilities
        </h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Non-founder liabilities — vendor payables, taxes, credit cards, and external loans.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total liabilities
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{debts.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Outstanding balance
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {formatCurrency(totalOutstanding)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueCount}</p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a liability</CardTitle>
          <CardDescription>Record a new debt or payable.</CardDescription>

          <form action={addDebt} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Counterparty
              </label>
              <input
                type="text"
                name="counterparty"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who is owed"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Principal (PKR)
              </label>
              <input
                type="number"
                name="principal"
                step="1"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Paid so far (PKR)
              </label>
              <input
                type="number"
                name="paidAmount"
                step="1"
                min="0"
                defaultValue={0}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="outstanding"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="outstanding">Outstanding</option>
                <option value="paid">Paid</option>
                <option value="overdue">Overdue</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add liability
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Debt & Liability Register</CardTitle>
          <CardDescription>Soonest due date first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Counterparty</th>
                  <th className="pb-2 pr-4">Due</th>
                  <th className="pb-2 pr-4 text-right">Principal</th>
                  <th className="pb-2 pr-4 text-right">Paid</th>
                  <th className="pb-2 pr-4 text-right">Remaining</th>
                  <th className="pb-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {debts.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No liabilities recorded yet.
                    </td>
                  </tr>
                )}
                {debts.map((d) => (
                  <tr key={d.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{d.counterparty}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {d.dueDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(d.principal)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-success">
                      {formatCurrency(d.paidAmount)}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-error">
                      {formatCurrency(d.remainingBalance)}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="debtId"
                        idValue={d.id}
                        status={d.status}
                        tone={
                          d.status === "paid"
                            ? "success"
                            : d.status === "overdue"
                              ? "error"
                              : "warning"
                        }
                        options={[
                          { value: "outstanding", label: "Outstanding" },
                          { value: "paid", label: "Paid" },
                          { value: "overdue", label: "Overdue" },
                        ]}
                        action={updateDebtStatus}
                      />
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
