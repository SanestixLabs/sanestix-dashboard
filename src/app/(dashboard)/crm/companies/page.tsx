import { Search } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { CompanyRow } from "@/components/crm/company-row";
import { getCrmCompanies } from "@/lib/supabase/queries";
import { addCompany, updateCompany, deleteCompany } from "@/app/(dashboard)/crm/actions";

export const dynamic = "force-dynamic";

export default async function CompaniesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; q?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").trim().toLowerCase();
  const allCompanies = await getCrmCompanies();
  const companies = q
    ? allCompanies.filter(
        (c) =>
          c.name.toLowerCase().includes(q) ||
          (c.industry ?? "").toLowerCase().includes(q)
      )
    : allCompanies;

  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Companies</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Organizations you sell to — one company can have many contacts and leads.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a company</CardTitle>
          <CardDescription>Register a new organization.</CardDescription>

          <form action={addCompany} className="mt-4 space-y-3">
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
                placeholder="e.g. Northwind Logistics"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Industry
              </label>
              <input
                type="text"
                name="industry"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Website
              </label>
              <input
                type="text"
                name="website"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Notes
              </label>
              <textarea
                name="notes"
                rows={3}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add company
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <CardTitle>Company Register</CardTitle>
              <CardDescription>
                {q
                  ? `${companies.length} of ${allCompanies.length} companies matching "${q}"`
                  : `All ${allCompanies.length} companies, newest first.`}
              </CardDescription>
            </div>
            <form className="relative w-full sm:w-56">
              <Search
                size={14}
                className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant"
              />
              <input
                type="text"
                name="q"
                defaultValue={params.q ?? ""}
                placeholder="Search name or industry"
                className="w-full border border-outline-variant bg-background py-1.5 pl-8 pr-3 font-mono-data text-[12px] placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none"
              />
            </form>
          </div>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[640px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Industry</th>
                  <th className="pb-2 pr-4">Contacts</th>
                  <th className="pb-2 pr-4">Leads</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {companies.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      {q ? `No companies match "${q}".` : "No companies recorded yet."}
                    </td>
                  </tr>
                )}
                {companies.map((c) => (
                  <CompanyRow
                    key={c.id}
                    company={c}
                    updateAction={updateCompany}
                    deleteAction={deleteCompany}
                  />
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </>
  );
}
