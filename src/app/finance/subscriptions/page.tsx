import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { formatCurrency } from "@/lib/utils";
import { getSubscriptions } from "@/lib/supabase/queries";
import { addSubscription, updateSubscriptionStatus } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function SubscriptionsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const subscriptions = await getSubscriptions();
  const active = subscriptions.filter((s) => s.status === "active");

  const monthlyBurn = active.reduce(
    (sum, s) => sum + (s.billingCycle === "monthly" ? s.cost : s.cost / 12),
    0
  );

  const today = new Date().toISOString().slice(0, 10);
  const in30Days = new Date();
  in30Days.setDate(in30Days.getDate() + 30);
  const upcomingRenewals = active.filter(
    (s) => s.renewalDate && s.renewalDate >= today && s.renewalDate <= in30Days.toISOString().slice(0, 10)
  ).length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Subscriptions"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Subscriptions</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Central register for monthly and annual tools — renewals, owners, and costs.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active subscriptions
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{active.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Estimated monthly burn
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(monthlyBurn)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Renewing in 30 days
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {upcomingRenewals}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a subscription</CardTitle>
          <CardDescription>Register a new recurring tool or service.</CardDescription>

          <form action={addSubscription} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Vendor / tool name
              </label>
              <input
                type="text"
                name="vendorName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. SEMrush"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Cost (PKR)
              </label>
              <input
                type="number"
                name="cost"
                step="1"
                min="0"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="0"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Billing cycle
              </label>
              <select
                name="billingCycle"
                defaultValue="monthly"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="monthly">Monthly</option>
                <option value="annual">Annual</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Renewal date
              </label>
              <input
                type="date"
                name="renewalDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Owner
              </label>
              <input
                type="text"
                name="owner"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who manages this"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add subscription
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Subscription Register</CardTitle>
          <CardDescription>Soonest renewal first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Vendor</th>
                  <th className="pb-2 pr-4">Cycle</th>
                  <th className="pb-2 pr-4">Renews</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4 text-right">Cost</th>
                  <th className="pb-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {subscriptions.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No subscriptions recorded yet.
                    </td>
                  </tr>
                )}
                {subscriptions.map((s) => (
                  <tr key={s.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{s.vendorName}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant capitalize">
                      {s.billingCycle}
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {s.renewalDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{s.owner ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(s.cost)}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="subscriptionId"
                        idValue={s.id}
                        status={s.status}
                        tone={s.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "cancelled", label: "Cancelled" },
                        ]}
                        action={updateSubscriptionStatus}
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
