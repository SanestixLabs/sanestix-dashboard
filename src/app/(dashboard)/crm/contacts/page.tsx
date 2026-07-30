import { Search } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { ContactRow } from "@/components/crm/contact-row";
import { getCrmContacts, getCrmCompanies } from "@/lib/supabase/queries";
import { addContact, updateContact, deleteContact } from "@/app/(dashboard)/crm/actions";

export const dynamic = "force-dynamic";

export default async function ContactsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; q?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").trim().toLowerCase();
  const [allContacts, companies] = await Promise.all([getCrmContacts(), getCrmCompanies()]);
  const contacts = q
    ? allContacts.filter(
        (c) =>
          c.fullName.toLowerCase().includes(q) ||
          (c.companyName ?? "").toLowerCase().includes(q) ||
          (c.email ?? "").toLowerCase().includes(q)
      )
    : allContacts;

  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Contacts</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          People at the companies you sell to. Optionally tied to a company.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a contact</CardTitle>
          <CardDescription>Register a new person.</CardDescription>

          <form action={addContact} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Full name
              </label>
              <input
                type="text"
                name="fullName"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. N. Aslam"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Company
              </label>
              <select
                name="companyId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Title
              </label>
              <input
                type="text"
                name="title"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Email
              </label>
              <input
                type="email"
                name="email"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Phone
              </label>
              <input
                type="text"
                name="phone"
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
              Add contact
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <CardTitle>Contact Register</CardTitle>
              <CardDescription>
                {q
                  ? `${contacts.length} of ${allContacts.length} contacts matching "${q}"`
                  : `All ${allContacts.length} contacts, newest first.`}
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
                placeholder="Search name, company, email"
                className="w-full border border-outline-variant bg-background py-1.5 pl-8 pr-3 font-mono-data text-[12px] placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none"
              />
            </form>
          </div>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Company</th>
                  <th className="pb-2 pr-4">Title</th>
                  <th className="pb-2 pr-4">Contact</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {contacts.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      {q ? `No contacts match "${q}".` : "No contacts recorded yet."}
                    </td>
                  </tr>
                )}
                {contacts.map((c) => (
                  <ContactRow
                    key={c.id}
                    contact={c}
                    companies={companies}
                    updateAction={updateContact}
                    deleteAction={deleteContact}
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
