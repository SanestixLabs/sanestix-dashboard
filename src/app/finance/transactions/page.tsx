import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";
import { addTransaction } from "@/app/finance/actions";

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
                  <th className="pb-2 text-right">Amount</th>
                </tr>
              </thead>
              <tbody>
                {transactions.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
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
                        "py-2.5 text-right font-mono-data " +
                        (t.kind === "revenue" ? "text-success" : "text-error")
                      }
                    >
                      {t.kind === "revenue" ? "+" : "-"}
                      {formatCurrency(t.amount)}
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
