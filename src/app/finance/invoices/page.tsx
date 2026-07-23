import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils";
import { getInvoices } from "@/lib/supabase/queries";
import { addInvoice, updateInvoiceStatus } from "@/app/finance/actions";
import { InvoiceStatusForm } from "@/components/finance/invoice-status-form";

export const dynamic = "force-dynamic";

export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const invoices = await getInvoices();

  const today = new Date().toISOString().slice(0, 10);
  const outstandingTotal = invoices
    .filter((i) => i.status === "outstanding")
    .reduce((sum, i) => sum + i.amount, 0);
  const overdueTotal = invoices
    .filter((i) => i.status === "overdue")
    .reduce((sum, i) => sum + i.amount, 0);
  const paidTotal = invoices
    .filter((i) => i.status === "paid")
    .reduce((sum, i) => sum + i.amount, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Invoices"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Invoices</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client invoices behind the Outstanding Invoices KPI, in PKR.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Outstanding
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(outstandingTotal)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {formatCurrency(overdueTotal)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Paid (all time)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(paidTotal)}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>New invoice</CardTitle>
          <CardDescription>Bill a client and track it through to payment.</CardDescription>

          <form action={addInvoice} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Client name
              </label>
              <input
                type="text"
                name="clientName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Systems Ltd"
              />
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

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                required
                defaultValue={today}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Create invoice
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>All invoices</CardTitle>
          <CardDescription>Sorted by due date. Update status inline.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Client</th>
                  <th className="pb-2 pr-4">Due date</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 pr-4">Logged by</th>
                  <th className="pb-2 text-right">Amount</th>
                </tr>
              </thead>
              <tbody>
                {invoices.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No invoices yet.
                    </td>
                  </tr>
                )}
                {invoices.map((inv) => (
                  <tr key={inv.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{inv.clientName}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {inv.dueDate}
                    </td>
                    <td className="py-2.5 pr-4">
                      <InvoiceStatusForm
                        invoiceId={inv.id}
                        status={inv.status}
                        action={updateInvoiceStatus}
                      />
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {inv.createdByName ?? "—"}
                    </td>
                    <td className="py-2.5 text-right font-mono-data text-on-surface">
                      {formatCurrency(inv.amount)}
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
