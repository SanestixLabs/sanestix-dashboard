import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { formatCurrency } from "@/lib/utils";
import { getAssets } from "@/lib/supabase/queries";
import { addAsset, updateAssetCondition, deleteAsset } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

const today = () => new Date().toISOString().slice(0, 10);

export default async function AssetsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const assets = await getAssets();
  const totalValue = assets
    .filter((a) => a.condition !== "disposed")
    .reduce((sum, a) => sum + a.cost, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Assets"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Assets</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Company-owned equipment and high-value purchases, tracked separately from expenses.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total assets
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{assets.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Book value (active)
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(totalValue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Disposed
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {assets.filter((a) => a.condition === "disposed").length}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add an asset</CardTitle>
          <CardDescription>Register new equipment or a high-value purchase.</CardDescription>

          <form action={addAsset} encType="multipart/form-data" className="mt-4 space-y-3">
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
                placeholder="e.g. Microphone"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Purchase date
              </label>
              <input
                type="date"
                name="purchaseDate"
                required
                defaultValue={today()}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
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
                Owner
              </label>
              <input
                type="text"
                name="owner"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Who holds this asset"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Serial number
              </label>
              <input
                type="text"
                name="serialNumber"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Condition
              </label>
              <select
                name="condition"
                defaultValue="good"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="new">New</option>
                <option value="good">Good</option>
                <option value="fair">Fair</option>
                <option value="poor">Poor</option>
                <option value="disposed">Disposed</option>
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Proof (optional)
              </label>
              <input
                type="file"
                name="proof"
                accept="image/*,application/pdf"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] file:mr-3 file:border-0 file:bg-primary/10 file:px-3 file:py-1.5 file:font-mono-data file:text-[11px] file:uppercase file:tracking-wider file:text-primary focus:border-primary focus:outline-none"
              />
              <p className="mt-1 text-[10px] text-on-surface-variant/70">
                Purchase receipt or invoice. Image or PDF, up to 5MB.
              </p>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add asset
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Asset Register</CardTitle>
          <CardDescription>Newest purchases first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[820px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Purchased</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4">Serial</th>
                  <th className="pb-2 pr-4 text-right">Cost</th>
                  <th className="pb-2 pr-4">Condition</th>
                  <th className="pb-2 pr-4">Proof</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {assets.length === 0 && (
                  <tr>
                    <td colSpan={8} className="py-6 text-center text-on-surface-variant">
                      No assets recorded yet.
                    </td>
                  </tr>
                )}
                {assets.map((a) => (
                  <tr key={a.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{a.name}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {a.purchaseDate}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{a.owner ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {a.serialNumber ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {formatCurrency(a.cost)}
                    </td>
                    <td className="py-2.5 pr-4">
                      <RegisterStatusForm
                        idFieldName="assetId"
                        idValue={a.id}
                        status={a.condition}
                        tone={
                          a.condition === "disposed"
                            ? "neutral"
                            : a.condition === "poor"
                              ? "error"
                              : a.condition === "fair"
                                ? "warning"
                                : "success"
                        }
                        options={[
                          { value: "new", label: "New" },
                          { value: "good", label: "Good" },
                          { value: "fair", label: "Fair" },
                          { value: "poor", label: "Poor" },
                          { value: "disposed", label: "Disposed" },
                        ]}
                        action={updateAssetCondition}
                      />
                    </td>
                    <td className="py-2.5 pr-4">
                      {a.proofUrl ? (
                        <a
                          href={a.proofUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="font-mono-data text-[11px] uppercase tracking-wider text-primary hover:underline"
                        >
                          View
                        </a>
                      ) : (
                        <span className="text-on-surface-variant">—</span>
                      )}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteAsset}
                          idFieldName="assetId"
                          idValue={a.id}
                          redirectTo="/finance/assets"
                          label="asset"
                        />
                      </div>
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
