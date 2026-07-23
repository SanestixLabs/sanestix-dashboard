import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { getVendors } from "@/lib/supabase/queries";
import { addVendor, updateVendorStatus } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

const CATEGORY_SUGGESTIONS = [
  "software",
  "hosting",
  "legal",
  "marketing",
  "equipment",
  "professional services",
];

export default async function VendorsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const vendors = await getVendors();
  const activeCount = vendors.filter((v) => v.status === "active").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Vendors"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Vendors</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Recurring suppliers and service providers, with contact and payment terms.
        </p>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total vendors
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{vendors.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">{activeCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Inactive
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {vendors.length - activeCount}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a vendor</CardTitle>
          <CardDescription>Register a new supplier or service provider.</CardDescription>

          <form action={addVendor} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Name
              </label>
              <input
                type="text"
                name="name"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Hostinger"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Category
              </label>
              <input
                type="text"
                name="category"
                list="vendor-category-suggestions"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. hosting"
              />
              <datalist id="vendor-category-suggestions">
                {CATEGORY_SUGGESTIONS.map((c) => (
                  <option key={c} value={c} />
                ))}
              </datalist>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact person
              </label>
              <input
                type="text"
                name="contactPerson"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact email
              </label>
              <input
                type="email"
                name="contactEmail"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Payment terms
              </label>
              <input
                type="text"
                name="paymentTerms"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Net 15"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="active"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add vendor
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Vendor Register</CardTitle>
          <CardDescription>All vendors, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Category</th>
                  <th className="pb-2 pr-4">Contact</th>
                  <th className="pb-2 pr-4">Terms</th>
                  <th className="pb-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {vendors.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No vendors recorded yet.
                    </td>
                  </tr>
                )}
                {vendors.map((v) => (
                  <tr key={v.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{v.name}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{v.category ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {v.contactPerson ?? v.contactEmail ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {v.paymentTerms ?? "—"}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="vendorId"
                        idValue={v.id}
                        status={v.status}
                        tone={v.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "inactive", label: "Inactive" },
                        ]}
                        action={updateVendorStatus}
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
