#!/usr/bin/env bash
# Sanestix — CRM production upgrades: edit lead/company/contact (previously
# add/delete only), search & filter on Leads/Companies/Contacts, and lost-
# reason tracking with a win/loss breakdown on the pipeline page.
#
# Run from the ROOT of your repo on the VPS. Safe to re-run.
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "ERROR: run this from the repo root (where package.json and src/app live)."
  exit 1
fi

echo "==> Step 1/4: patching src/lib/types.ts and src/lib/supabase/queries.ts"
python3 - << 'PYEOF'
import pathlib, sys

patches = [
    ("src/lib/types.ts", [
        (
'''export type LeadStage = "new" | "contacted" | "qualified" | "proposal" | "won" | "lost";

export const LEAD_STAGES: { value: LeadStage; label: string }[] = [
  { value: "new", label: "New" },
  { value: "contacted", label: "Contacted" },
  { value: "qualified", label: "Qualified" },
  { value: "proposal", label: "Proposal" },
  { value: "won", label: "Won" },
  { value: "lost", label: "Lost" },
];
''',
'''export type LeadStage = "new" | "contacted" | "qualified" | "proposal" | "won" | "lost";

export const LEAD_STAGES: { value: LeadStage; label: string }[] = [
  { value: "new", label: "New" },
  { value: "contacted", label: "Contacted" },
  { value: "qualified", label: "Qualified" },
  { value: "proposal", label: "Proposal" },
  { value: "won", label: "Won" },
  { value: "lost", label: "Lost" },
];

// Shown as a dropdown when a lead is marked "lost", so win/loss reporting
// on the CRM pipeline page has something more useful than a raw count.
export const LOST_REASONS = [
  "Budget",
  "Timing",
  "Went with a competitor",
  "No response / went cold",
  "Not a good fit",
  "Other",
] as const;
'''
        ),
        (
'''  expectedCloseDate: string | null;
  notes: string | null;
  convertedProjectId: string | null;''',
'''  expectedCloseDate: string | null;
  notes: string | null;
  lostReason: string | null;
  convertedProjectId: string | null;'''
        ),
    ]),
    ("src/lib/supabase/queries.ts", [
        (
'''        `id, title, company_id, contact_id, stage, value, source, owner_id,
         expected_close_date, notes, converted_project_id, created_at, updated_at,
         crm_companies(name),''',
'''        `id, title, company_id, contact_id, stage, value, source, owner_id,
         expected_close_date, notes, lost_reason, converted_project_id, created_at, updated_at,
         crm_companies(name),'''
        ),
        (
'''      expectedCloseDate: row.expected_close_date,
      notes: row.notes,
      convertedProjectId: row.converted_project_id,''',
'''      expectedCloseDate: row.expected_close_date,
      notes: row.notes,
      lostReason: row.lost_reason,
      convertedProjectId: row.converted_project_id,'''
        ),
    ]),
]

failed = False
for filename, replacements in patches:
    p = pathlib.Path(filename)
    if not p.exists():
        print("MISSING FILE:", filename)
        failed = True
        continue
    s = p.read_text()
    for old, new in replacements:
        if new in s:
            print(f"SKIP (already patched): {filename}")
            continue
        if old not in s:
            print(f"PATTERN NOT FOUND in {filename}:")
            print(old[:120])
            failed = True
            continue
        s = s.replace(old, new, 1)
    p.write_text(s)
    print("OK", filename)

if failed:
    sys.exit(1)
PYEOF

echo "==> Step 2/4: writing new CRM components"
mkdir -p src/components/crm

cat > src/components/crm/edit-toggle.tsx << 'EDITTOGGLE_EOF'
"use client";

import { useState } from "react";
import { Pencil, X } from "lucide-react";

export function EditToggle({
  label = "Edit",
  children,
}: {
  label?: string;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={label}
        title={label}
        className="inline-flex items-center gap-1 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant transition hover:text-primary"
      >
        <Pencil size={12} />
        {label}
      </button>
    );
  }

  return (
    <div className="mt-3 border border-outline-variant bg-background p-3">
      <div className="mb-2 flex items-center justify-between">
        <span className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
          Editing
        </span>
        <button
          type="button"
          onClick={() => setOpen(false)}
          aria-label="Cancel edit"
          title="Cancel"
          className="text-on-surface-variant transition hover:text-on-surface"
        >
          <X size={13} />
        </button>
      </div>
      {children}
    </div>
  );
}
EDITTOGGLE_EOF

cat > src/components/crm/company-row.tsx << 'COMPANYROW_EOF'
"use client";

import { useState } from "react";
import { Pencil } from "lucide-react";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import type { CrmCompany } from "@/lib/types";

export function CompanyRow({
  company,
  updateAction,
  deleteAction,
}: {
  company: CrmCompany;
  updateAction: (formData: FormData) => void;
  deleteAction: (formData: FormData) => void;
}) {
  const [editing, setEditing] = useState(false);

  if (editing) {
    return (
      <tr className="border-b border-outline-variant/50 bg-surface-container-high/40">
        <td colSpan={5} className="py-3 pr-4">
          <form action={updateAction} className="flex flex-wrap items-end gap-2">
            <input type="hidden" name="companyId" value={company.id} />
            <div className="min-w-[160px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Name
              </label>
              <input
                name="name"
                defaultValue={company.name}
                required
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[140px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Industry
              </label>
              <input
                name="industry"
                defaultValue={company.industry ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[160px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Website
              </label>
              <input
                name="website"
                defaultValue={company.website ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[200px] flex-[2]">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Notes
              </label>
              <input
                name="notes"
                defaultValue={company.notes ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="flex gap-1.5">
              <button
                type="submit"
                className="bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
              >
                Save
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="border border-outline-variant px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant transition hover:text-on-surface"
              >
                Cancel
              </button>
            </div>
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-outline-variant/50">
      <td className="py-2.5 pr-4 text-on-surface">
        {company.website ? (
          <a
            href={company.website.startsWith("http") ? company.website : `https://${company.website}`}
            target="_blank"
            rel="noreferrer"
            className="hover:text-primary hover:underline"
          >
            {company.name}
          </a>
        ) : (
          company.name
        )}
      </td>
      <td className="py-2.5 pr-4 text-on-surface-variant">{company.industry ?? "—"}</td>
      <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">{company.contactCount}</td>
      <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">{company.leadCount}</td>
      <td className="py-2.5 text-right">
        <div className="flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={() => setEditing(true)}
            aria-label="Edit company"
            title="Edit"
            className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-surface-container-high hover:text-primary"
          >
            <Pencil size={14} />
          </button>
          <RegisterDeleteButton
            action={deleteAction}
            idFieldName="companyId"
            idValue={company.id}
            redirectTo="/crm/companies"
            label="company"
          />
        </div>
      </td>
    </tr>
  );
}
COMPANYROW_EOF

cat > src/components/crm/contact-row.tsx << 'CONTACTROW_EOF'
"use client";

import { useState } from "react";
import { Pencil } from "lucide-react";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import type { CrmCompany, CrmContact } from "@/lib/types";

export function ContactRow({
  contact,
  companies,
  updateAction,
  deleteAction,
}: {
  contact: CrmContact;
  companies: CrmCompany[];
  updateAction: (formData: FormData) => void;
  deleteAction: (formData: FormData) => void;
}) {
  const [editing, setEditing] = useState(false);

  if (editing) {
    return (
      <tr className="border-b border-outline-variant/50 bg-surface-container-high/40">
        <td colSpan={5} className="py-3 pr-4">
          <form action={updateAction} className="flex flex-wrap items-end gap-2">
            <input type="hidden" name="contactId" value={contact.id} />
            <div className="min-w-[160px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Full name
              </label>
              <input
                name="fullName"
                defaultValue={contact.fullName}
                required
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[140px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Company
              </label>
              <select
                name="companyId"
                defaultValue={contact.companyId ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {companies.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="min-w-[120px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Title
              </label>
              <input
                name="title"
                defaultValue={contact.title ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[160px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Email
              </label>
              <input
                name="email"
                type="email"
                defaultValue={contact.email ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="min-w-[130px] flex-1">
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Phone
              </label>
              <input
                name="phone"
                defaultValue={contact.phone ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <div className="flex gap-1.5">
              <button
                type="submit"
                className="bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
              >
                Save
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="border border-outline-variant px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant transition hover:text-on-surface"
              >
                Cancel
              </button>
            </div>
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-outline-variant/50">
      <td className="py-2.5 pr-4 text-on-surface">{contact.fullName}</td>
      <td className="py-2.5 pr-4 text-on-surface-variant">{contact.companyName ?? "—"}</td>
      <td className="py-2.5 pr-4 text-on-surface-variant">{contact.title ?? "—"}</td>
      <td className="py-2.5 pr-4 text-on-surface-variant">{contact.email ?? contact.phone ?? "—"}</td>
      <td className="py-2.5 text-right">
        <div className="flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={() => setEditing(true)}
            aria-label="Edit contact"
            title="Edit"
            className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-surface-container-high hover:text-primary"
          >
            <Pencil size={14} />
          </button>
          <RegisterDeleteButton
            action={deleteAction}
            idFieldName="contactId"
            idValue={contact.id}
            redirectTo="/crm/contacts"
            label="contact"
          />
        </div>
      </td>
    </tr>
  );
}
CONTACTROW_EOF

echo "==> Step 3/4: writing updated CRM actions and pages"

cat > "src/app/(dashboard)/crm/actions.ts" << 'CRMACTIONS_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { confirmPasswordOrRedirect } from "@/lib/auth-confirm";
import { recordActivity } from "@/lib/audit";
import { LEAD_STAGES } from "@/lib/types";

const VALID_STAGES = LEAD_STAGES.map((s) => s.value);

// ---------------------------------------------------------------------------
// Companies
// ---------------------------------------------------------------------------

export async function addCompany(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const industry = String(formData.get("industry") ?? "") || null;
  const website = String(formData.get("website") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!name) redirect("/crm/companies?error=Please enter a company name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_companies")
    .insert({ name, industry, website, notes, created_by: user?.id ?? null })
    .select("id")
    .single();

  if (error) redirect(`/crm/companies?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_companies",
    entityId: inserted?.id ?? null,
    summary: `Company "${name}" added`,
    notify: false,
  });

  revalidatePath("/crm/companies");
  redirect("/crm/companies");
}

export async function updateCompany(formData: FormData) {
  const companyId = String(formData.get("companyId") ?? "");
  const name = String(formData.get("name") ?? "").trim();
  const industry = String(formData.get("industry") ?? "") || null;
  const website = String(formData.get("website") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;
  const redirectTo = "/crm/companies";

  if (!companyId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing company id")}`);
  if (!name) redirect(`${redirectTo}?error=${encodeURIComponent("Please enter a company name")}`);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("crm_companies")
    .update({ name, industry, website, notes })
    .eq("id", companyId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_companies",
    entityId: companyId,
    summary: `Company "${name}" updated`,
    notify: false,
  });

  revalidatePath(redirectTo);
  redirect(redirectTo);
}

export async function deleteCompany(formData: FormData) {
  const companyId = String(formData.get("companyId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/companies";

  if (!companyId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing company id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_companies")
    .select("name")
    .eq("id", companyId)
    .maybeSingle();
  const { error } = await supabase.from("crm_companies").delete().eq("id", companyId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_companies",
    entityId: companyId,
    summary: `Company "${existing?.name ?? companyId}" deleted`,
    notify: true,
    notifyLink: "/crm/companies",
  });

  revalidatePath("/crm/companies");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Contacts
// ---------------------------------------------------------------------------

export async function addContact(formData: FormData) {
  const fullName = String(formData.get("fullName") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const email = String(formData.get("email") ?? "") || null;
  const phone = String(formData.get("phone") ?? "") || null;
  const title = String(formData.get("title") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!fullName) redirect("/crm/contacts?error=Please enter a contact name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_contacts")
    .insert({
      full_name: fullName,
      company_id: companyId,
      email,
      phone,
      title,
      notes,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm/contacts?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_contacts",
    entityId: inserted?.id ?? null,
    summary: `Contact "${fullName}" added`,
    notify: false,
  });

  revalidatePath("/crm/contacts");
  redirect("/crm/contacts");
}

export async function updateContact(formData: FormData) {
  const contactId = String(formData.get("contactId") ?? "");
  const fullName = String(formData.get("fullName") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const email = String(formData.get("email") ?? "") || null;
  const phone = String(formData.get("phone") ?? "") || null;
  const title = String(formData.get("title") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;
  const redirectTo = "/crm/contacts";

  if (!contactId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing contact id")}`);
  if (!fullName) redirect(`${redirectTo}?error=${encodeURIComponent("Please enter a contact name")}`);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("crm_contacts")
    .update({ full_name: fullName, company_id: companyId, email, phone, title, notes })
    .eq("id", contactId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_contacts",
    entityId: contactId,
    summary: `Contact "${fullName}" updated`,
    notify: false,
  });

  revalidatePath(redirectTo);
  redirect(redirectTo);
}

export async function deleteContact(formData: FormData) {
  const contactId = String(formData.get("contactId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/contacts";

  if (!contactId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing contact id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_contacts")
    .select("full_name")
    .eq("id", contactId)
    .maybeSingle();
  const { error } = await supabase.from("crm_contacts").delete().eq("id", contactId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_contacts",
    entityId: contactId,
    summary: `Contact "${existing?.full_name ?? contactId}" deleted`,
    notify: true,
    notifyLink: "/crm/contacts",
  });

  revalidatePath("/crm/contacts");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Leads (the pipeline)
// ---------------------------------------------------------------------------

export async function addLead(formData: FormData) {
  const title = String(formData.get("title") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const contactId = String(formData.get("contactId") ?? "") || null;
  const value = Number(formData.get("value") ?? 0);
  const source = String(formData.get("source") ?? "") || null;
  const expectedCloseDate = String(formData.get("expectedCloseDate") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!title || value < 0) {
    redirect("/crm?error=Please fill in the lead title with a valid value");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_leads")
    .insert({
      title,
      company_id: companyId,
      contact_id: contactId,
      value,
      source,
      owner_id: user?.id ?? null,
      expected_close_date: expectedCloseDate,
      notes,
      stage: "new",
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_leads",
    entityId: inserted?.id ?? null,
    summary: `New lead "${title}"`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect("/crm");
}

/**
 * Edit a lead's details (title, company/contact links, value, source,
 * expected close date, notes). Deliberately does NOT touch `stage` —
 * stage changes go through updateLeadStage below, which has the "won"
 * → auto-create-project side effect that a plain edit shouldn't trigger.
 */
export async function updateLead(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const contactId = String(formData.get("contactId") ?? "") || null;
  const value = Number(formData.get("value") ?? 0);
  const source = String(formData.get("source") ?? "") || null;
  const expectedCloseDate = String(formData.get("expectedCloseDate") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;
  const redirectTo = String(formData.get("redirectTo") ?? "/crm");

  if (!leadId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing lead id")}`);
  if (!title || value < 0) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please fill in the lead title with a valid value")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("crm_leads")
    .update({
      title,
      company_id: companyId,
      contact_id: contactId,
      value,
      source,
      expected_close_date: expectedCloseDate,
      notes,
    })
    .eq("id", leadId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_leads",
    entityId: leadId,
    summary: `Lead "${title}" details updated`,
    notify: false,
  });

  revalidatePath("/crm");
  revalidatePath(`/crm/leads/${leadId}`);
  redirect(redirectTo);
}

/**
 * Move a lead to a new pipeline stage. Moving a lead to "won" auto-creates
 * a draft Project row and links it back via converted_project_id — this is
 * the real CRM → Projects handoff (not just two disconnected modules).
 * Safe to call repeatedly: if the lead was already won, it won't create a
 * second project.
 */
export async function updateLeadStage(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const stage = String(formData.get("stage") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm");

  if (!leadId || !VALID_STAGES.includes(stage as (typeof VALID_STAGES)[number])) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid stage update")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: lead } = await supabase
    .from("crm_leads")
    .select("id, title, value, company_id, converted_project_id, stage")
    .eq("id", leadId)
    .maybeSingle();

  if (!lead) redirect(`${redirectTo}?error=${encodeURIComponent("Lead not found")}`);

  const { error } = await supabase.from("crm_leads").update({ stage }).eq("id", leadId);
  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind: "stage_change",
    content: `Stage changed to "${stage}"`,
    created_by: user?.id ?? null,
  });

  let projectId: string | null = null;

  if (stage === "won" && !lead.converted_project_id) {
    const { data: project, error: projectError } = await supabase
      .from("projects")
      .insert({
        name: lead.title,
        company_id: lead.company_id,
        status: "on_track",
        source_lead_id: leadId,
        notes: `Auto-created from won lead (deal value ${lead.value}).`,
        created_by: user?.id ?? null,
      })
      .select("id")
      .single();

    if (!projectError && project) {
      projectId = project.id;
      await supabase.from("crm_leads").update({ converted_project_id: project.id }).eq("id", leadId);
    }
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_leads",
    entityId: leadId,
    summary: projectId
      ? `Lead "${lead.title}" won — draft project created`
      : `Lead "${lead.title}" moved to ${stage}`,
    notify: stage === "won",
    notifyLink: projectId ? "/projects" : "/crm",
  });

  revalidatePath("/crm");
  revalidatePath(`/crm/leads/${leadId}`);
  revalidatePath("/projects");
  redirect(redirectTo);
}

/**
 * Set or change why a "lost" lead was lost. Kept as its own tiny action
 * (rather than a field on updateLeadStage) because the stage dropdown
 * auto-submits on change — there's no good moment in that flow to also
 * collect a reason, so it's captured separately on the lead detail page
 * once the lead is already in the "lost" stage.
 */
export async function updateLeadLostReason(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const lostReason = String(formData.get("lostReason") ?? "").trim() || null;
  const redirectTo = String(formData.get("redirectTo") ?? "/crm");

  if (!leadId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing lead id")}`);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: lead } = await supabase
    .from("crm_leads")
    .select("title, stage")
    .eq("id", leadId)
    .maybeSingle();

  if (!lead) redirect(`${redirectTo}?error=${encodeURIComponent("Lead not found")}`);
  if (lead.stage !== "lost") {
    redirect(`${redirectTo}?error=${encodeURIComponent("Only a lost lead can have a lost reason")}`);
  }

  const { error } = await supabase
    .from("crm_leads")
    .update({ lost_reason: lostReason })
    .eq("id", leadId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_leads",
    entityId: leadId,
    summary: lostReason
      ? `Lost reason for "${lead.title}" set to "${lostReason}"`
      : `Lost reason for "${lead.title}" cleared`,
    notify: false,
  });

  revalidatePath("/crm");
  revalidatePath(`/crm/leads/${leadId}`);
  redirect(redirectTo);
}

export async function deleteLead(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm";

  if (!leadId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing lead id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_leads")
    .select("title")
    .eq("id", leadId)
    .maybeSingle();
  const { error } = await supabase.from("crm_leads").delete().eq("id", leadId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_leads",
    entityId: leadId,
    summary: `Lead "${existing?.title ?? leadId}" deleted`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead notes / activity log
// ---------------------------------------------------------------------------

export async function addLeadNote(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const kind = String(formData.get("kind") ?? "note");
  const content = String(formData.get("content") ?? "").trim();
  const redirectTo = `/crm/leads/${leadId}`;

  if (!leadId || !content) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please write a note before saving")}`);
  }
  if (!["note", "call", "email", "meeting"].includes(kind)) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid note type")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind,
    content,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  // Touch updated_at so the lead surfaces near the top of "recently active".
  await supabase.from("crm_leads").update({ updated_at: new Date().toISOString() }).eq("id", leadId);

  revalidatePath(redirectTo);
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead follow-up tasks
// ---------------------------------------------------------------------------

export async function addLeadTask(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const dueDate = String(formData.get("dueDate") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? `/crm/leads/${leadId}`);

  if (!leadId || !title || !dueDate) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please fill in the task title and due date")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_tasks").insert({
    lead_id: leadId,
    title,
    due_date: dueDate,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function toggleLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const done = formData.get("done") === "true";
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").update({ done: !done }).eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function deleteLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").delete().eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}
CRMACTIONS_EOF

cat > "src/app/(dashboard)/crm/companies/page.tsx" << 'CRMCOMPANIES_EOF'
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
CRMCOMPANIES_EOF

cat > "src/app/(dashboard)/crm/contacts/page.tsx" << 'CRMCONTACTS_EOF'
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
CRMCONTACTS_EOF

cat > "src/app/(dashboard)/crm/page.tsx" << 'CRMPIPELINE_EOF'
import Link from "next/link";
import { Search } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getCrmLeads, getCrmCompanies, getCrmContacts } from "@/lib/supabase/queries";
import { addLead, updateLeadStage, deleteLead } from "@/app/(dashboard)/crm/actions";
import { LEAD_STAGES, type LeadStage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

const BOARD_STAGES = LEAD_STAGES.filter((s) => s.value !== "lost");

export default async function CrmPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; q?: string }>;
}) {
  const params = await searchParams;
  const q = (params.q ?? "").trim().toLowerCase();
  const [allLeads, companies, contacts] = await Promise.all([
    getCrmLeads(),
    getCrmCompanies(),
    getCrmContacts(),
  ]);

  const leads = q
    ? allLeads.filter(
        (l) =>
          l.title.toLowerCase().includes(q) ||
          (l.companyName ?? "").toLowerCase().includes(q) ||
          (l.contactName ?? "").toLowerCase().includes(q)
      )
    : allLeads;

  const openLeads = leads.filter((l) => l.stage !== "won" && l.stage !== "lost");
  const pipelineValue = openLeads.reduce((sum, l) => sum + l.value, 0);
  const wonThisMonth = leads.filter((l) => {
    if (l.stage !== "won") return false;
    const d = new Date(l.updatedAt);
    const now = new Date();
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  }).length;
  const lostLeads = leads.filter((l) => l.stage === "lost");
  const lostCount = lostLeads.length;

  const lostReasonCounts = new Map<string, number>();
  for (const lead of lostLeads) {
    const key = lead.lostReason ?? "No reason recorded";
    lostReasonCounts.set(key, (lostReasonCounts.get(key) ?? 0) + 1);
  }
  const lostReasonBreakdown = [...lostReasonCounts.entries()].sort((a, b) => b[1] - a[1]);

  return (
    <>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">CRM Pipeline</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Leads from intake to closed work. Moving a lead to Won creates a draft project
            automatically.
          </p>
        </div>
        <form className="relative w-full sm:w-64">
          <Search
            size={14}
            className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant"
          />
          <input
            type="text"
            name="q"
            defaultValue={params.q ?? ""}
            placeholder="Search title, company, contact"
            className="w-full border border-outline-variant bg-background py-2 pl-8 pr-3 font-mono-data text-[12px] placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none"
          />
        </form>
      </div>
      {q && (
        <p className="text-[12px] text-on-surface-variant">
          Showing {leads.length} of {allLeads.length} leads matching &quot;{q}&quot; ·{" "}
          <Link href="/crm" className="text-primary hover:underline">
            clear
          </Link>
        </p>
      )}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Open leads
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-primary">{openLeads.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Pipeline value
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(pipelineValue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Won this month
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{wonThisMonth}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Lost
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {lostCount}
          </p>
        </Card>
      </div>

      {lostReasonBreakdown.length > 0 && (
        <Card className="p-4">
          <p className="mb-3 text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Why leads are lost
          </p>
          <div className="flex flex-wrap gap-2">
            {lostReasonBreakdown.map(([reason, count]) => (
              <span
                key={reason}
                className="inline-flex items-center gap-1.5 border border-outline-variant bg-background px-2.5 py-1 text-[11px] text-on-surface-variant"
              >
                {reason}
                <span className="font-mono-data font-semibold text-on-surface">{count}</span>
              </span>
            ))}
          </div>
        </Card>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <Card className="p-6 lg:col-span-1">
          <CardTitle>Add a lead</CardTitle>
          <CardDescription>New pipeline entry, starts at stage &quot;New&quot;.</CardDescription>

          <form action={addLead} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Lead title
              </label>
              <input
                type="text"
                name="title"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Marwaa Memorials — Website"
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
                Contact
              </label>
              <select
                name="contactId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.fullName}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Deal value (PKR)
              </label>
              <input
                type="number"
                name="value"
                min="0"
                step="0.01"
                defaultValue="0"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Source
              </label>
              <input
                type="text"
                name="source"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Website form, referral"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Expected close date
              </label>
              <input
                type="date"
                name="expectedCloseDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add lead
            </button>
          </form>

          <div className="mt-6 flex flex-col gap-2 border-t border-outline-variant pt-4 text-[11px]">
            <Link href="/crm/companies" className="text-on-surface-variant hover:text-primary">
              Manage companies →
            </Link>
            <Link href="/crm/contacts" className="text-on-surface-variant hover:text-primary">
              Manage contacts →
            </Link>
            <Link href="/crm/tasks" className="text-on-surface-variant hover:text-primary">
              Follow-up tasks →
            </Link>
          </div>
        </Card>

        <div className="lg:col-span-3">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {BOARD_STAGES.map((stage) => {
              const stageLeads = leads.filter((l) => l.stage === stage.value);
              return (
                <div key={stage.value} className="flex min-w-0 flex-col">
                  <div className="mb-2 flex items-center justify-between px-1">
                    <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                      {stage.label}
                    </span>
                    <span className="font-mono-data text-[11px] text-on-surface-variant/70">
                      {stageLeads.length}
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-2">
                    {stageLeads.length === 0 && (
                      <Card className="p-3 text-center text-[11px] text-on-surface-variant/60">
                        Empty
                      </Card>
                    )}
                    {stageLeads.map((lead) => (
                      <Card key={lead.id} className="p-3">
                        <Link
                          href={`/crm/leads/${lead.id}`}
                          className="block text-[13px] font-medium text-on-surface hover:text-primary"
                        >
                          {lead.title}
                        </Link>
                        <p className="mt-0.5 truncate text-[11px] text-on-surface-variant">
                          {lead.companyName ?? lead.contactName ?? "—"}
                        </p>
                        <p className="mt-1 font-mono-data text-[12px] font-semibold text-success">
                          {formatCurrency(lead.value)}
                        </p>
                        {lead.overdueTaskCount > 0 && (
                          <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-error">
                            {lead.overdueTaskCount} overdue task{lead.overdueTaskCount > 1 ? "s" : ""}
                          </p>
                        )}
                        <div className="mt-2 flex items-center justify-between gap-2">
                          <RegisterStatusForm
                            idFieldName="leadId"
                            idValue={lead.id}
                            status={lead.stage}
                            tone={STAGE_TONE[lead.stage]}
                            options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                            action={updateLeadStage}
                            extraFields={{ redirectTo: "/crm" }}
                          />
                          <RegisterDeleteButton
                            action={deleteLead}
                            idFieldName="leadId"
                            idValue={lead.id}
                            redirectTo="/crm"
                            label="lead"
                          />
                        </div>
                      </Card>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </>
  );
}
CRMPIPELINE_EOF

mkdir -p "src/app/(dashboard)/crm/leads/[id]"
cat > "src/app/(dashboard)/crm/leads/[id]/page.tsx" << 'CRMLEADDETAIL_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { SetBreadcrumb } from "@/components/layout/breadcrumb-context";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { TaskToggleCheckbox } from "@/components/crm/task-toggle-checkbox";
import { EditToggle } from "@/components/crm/edit-toggle";
import {
  getCrmLead,
  getLeadActivities,
  getOpenLeadTasks,
  getCrmCompanies,
  getCrmContacts,
} from "@/lib/supabase/queries";
import {
  updateLead,
  updateLeadStage,
  updateLeadLostReason,
  deleteLead,
  addLeadNote,
  addLeadTask,
  toggleLeadTask,
  deleteLeadTask,
} from "@/app/(dashboard)/crm/actions";
import { LEAD_STAGES, LOST_REASONS, type LeadStage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

const ACTIVITY_LABEL: Record<string, string> = {
  note: "Note",
  call: "Call",
  email: "Email",
  meeting: "Meeting",
  stage_change: "Stage change",
};

export default async function LeadDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { id } = await params;
  const search = await searchParams;
  const lead = await getCrmLead(id);
  if (!lead) notFound();

  const [activities, allOpenTasks, companies, contacts] = await Promise.all([
    getLeadActivities(id),
    getOpenLeadTasks(),
    getCrmCompanies(),
    getCrmContacts(),
  ]);
  const leadTasks = allOpenTasks.filter((t) => t.leadId === id);
  const redirectTo = `/crm/leads/${id}`;

  return (
    <>
    <SetBreadcrumb crumbs={["Sanestix OS", "CRM", lead.title]} />
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <Link href="/crm" className="text-[11px] text-on-surface-variant hover:text-primary">
            ← Back to pipeline
          </Link>
          <h1 className="mt-2 text-[28px] font-bold tracking-tight text-on-surface">{lead.title}</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            {lead.companyName ?? "No company"} · {lead.contactName ?? "No contact"}
          </p>
        </div>
        <RegisterDeleteButton
          action={deleteLead}
          idFieldName="leadId"
          idValue={lead.id}
          redirectTo="/crm"
          label="lead"
        />
      </div>

      {lead.convertedProjectId && (
        <Card className="flex items-center justify-between border-success/30 bg-success/[0.06] p-4">
          <p className="text-[13px] text-on-surface">
            This lead was won and auto-created a draft project.
          </p>
          <Link
            href="/projects"
            className="inline-flex items-center gap-1 text-[12px] font-mono-data uppercase tracking-wider text-success hover:brightness-110"
          >
            View project <ArrowRight size={14} />
          </Link>
        </Card>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Details</CardTitle>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Stage</span>
              <RegisterStatusForm
                idFieldName="leadId"
                idValue={lead.id}
                status={lead.stage}
                tone={STAGE_TONE[lead.stage]}
                options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                action={updateLeadStage}
                extraFields={{ redirectTo }}
              />
            </div>
            {lead.stage === "lost" && (
              <div className="flex items-center justify-between gap-3">
                <span className="text-on-surface-variant">Lost reason</span>
                <span className="text-right text-on-surface">{lead.lostReason ?? "—"}</span>
              </div>
            )}
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Value</span>
              <span className="font-mono-data font-semibold text-success">
                {formatCurrency(lead.value)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Owner</span>
              <span className="text-on-surface">{lead.ownerName ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Source</span>
              <span className="text-on-surface">{lead.source ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Expected close</span>
              <span className="font-mono-data text-on-surface">
                {lead.expectedCloseDate
                  ? new Date(lead.expectedCloseDate).toLocaleDateString()
                  : "—"}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Contact email</span>
              <span className="text-on-surface">{lead.contactEmail ?? "—"}</span>
            </div>
            {lead.notes && (
              <div className="border-t border-outline-variant pt-3">
                <span className="text-on-surface-variant">Notes</span>
                <p className="mt-1 text-on-surface">{lead.notes}</p>
              </div>
            )}
          </div>

          {lead.stage === "lost" && (
            <div className="mt-4 border-t border-outline-variant pt-4">
              <EditToggle label={lead.lostReason ? "Change lost reason" : "Set lost reason"}>
                <form action={updateLeadLostReason} className="space-y-2">
                  <input type="hidden" name="leadId" value={lead.id} />
                  <input type="hidden" name="redirectTo" value={redirectTo} />
                  <select
                    name="lostReason"
                    defaultValue={lead.lostReason ?? ""}
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  >
                    <option value="">— No reason —</option>
                    {LOST_REASONS.map((reason) => (
                      <option key={reason} value={reason}>
                        {reason}
                      </option>
                    ))}
                  </select>
                  <button
                    type="submit"
                    className="w-full bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
                  >
                    Save
                  </button>
                </form>
              </EditToggle>
            </div>
          )}

          <div className="mt-4 border-t border-outline-variant pt-4">
            <EditToggle label="Edit lead details">
              <form action={updateLead} className="space-y-2.5">
                <input type="hidden" name="leadId" value={lead.id} />
                <input type="hidden" name="redirectTo" value={redirectTo} />
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Title
                  </label>
                  <input
                    name="title"
                    defaultValue={lead.title}
                    required
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Company
                    </label>
                    <select
                      name="companyId"
                      defaultValue={lead.companyId ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
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
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Contact
                    </label>
                    <select
                      name="contactId"
                      defaultValue={lead.contactId ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    >
                      <option value="">— None —</option>
                      {contacts.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.fullName}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Value (PKR)
                    </label>
                    <input
                      name="value"
                      type="number"
                      min="0"
                      step="0.01"
                      defaultValue={lead.value}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Expected close
                    </label>
                    <input
                      name="expectedCloseDate"
                      type="date"
                      defaultValue={lead.expectedCloseDate ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    />
                  </div>
                </div>
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Source
                  </label>
                  <input
                    name="source"
                    defaultValue={lead.source ?? ""}
                    placeholder="e.g. Referral, Website, LinkedIn"
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Notes
                  </label>
                  <textarea
                    name="notes"
                    rows={2}
                    defaultValue={lead.notes ?? ""}
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <button
                  type="submit"
                  className="w-full bg-primary px-3 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
                >
                  Save changes
                </button>
              </form>
            </EditToggle>
          </div>

          <div className="mt-6 border-t border-outline-variant pt-4">
            <CardTitle>Follow-up tasks</CardTitle>
            <div className="mt-3 space-y-2">
              {leadTasks.length === 0 && (
                <p className="text-[12px] text-on-surface-variant">No open tasks.</p>
              )}
              {leadTasks.map((t) => (
                <div key={t.id} className="flex items-center gap-2 text-[12px]">
                  <TaskToggleCheckbox
                    action={toggleLeadTask}
                    taskId={t.id}
                    done={t.done}
                    redirectTo={redirectTo}
                  />
                  <span className="min-w-0 flex-1 truncate text-on-surface">{t.title}</span>
                  <StatusPill tone={t.overdue ? "error" : "neutral"}>
                    {new Date(t.dueDate).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                    })}
                  </StatusPill>
                  <form action={deleteLeadTask}>
                    <input type="hidden" name="taskId" value={t.id} />
                    <input type="hidden" name="redirectTo" value={redirectTo} />
                    <button
                      type="submit"
                      aria-label="Delete task"
                      className="text-on-surface-variant hover:text-error"
                    >
                      ✕
                    </button>
                  </form>
                </div>
              ))}
            </div>

            <form action={addLeadTask} className="mt-3 flex flex-col gap-2">
              <input type="hidden" name="leadId" value={lead.id} />
              <input type="hidden" name="redirectTo" value={redirectTo} />
              <input
                type="text"
                name="title"
                required
                placeholder="e.g. Call back Thursday"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
              <div className="flex gap-2">
                <input
                  type="date"
                  name="dueDate"
                  required
                  className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                />
                <button
                  type="submit"
                  className="bg-primary px-3 py-2 font-mono-data text-[10px] uppercase tracking-wider text-on-primary hover:brightness-110"
                >
                  Add
                </button>
              </div>
            </form>
          </div>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Activity</CardTitle>
          <CardDescription>Notes, calls, emails, meetings, and stage changes.</CardDescription>

          <form action={addLeadNote} className="mt-4 space-y-2 border-b border-outline-variant pb-4">
            <input type="hidden" name="leadId" value={lead.id} />
            {search.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {search.error}
              </div>
            )}
            <div className="flex gap-2">
              <select
                name="kind"
                defaultValue="note"
                className="border border-outline-variant bg-background px-2 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="note">Note</option>
                <option value="call">Call</option>
                <option value="email">Email</option>
                <option value="meeting">Meeting</option>
              </select>
              <textarea
                name="content"
                required
                rows={2}
                placeholder="What happened?"
                className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary hover:brightness-110"
            >
              Log activity
            </button>
          </form>

          <div className="mt-4 max-h-[520px] space-y-4 overflow-auto">
            {activities.length === 0 && (
              <p className="py-6 text-center text-[13px] text-on-surface-variant">
                No activity logged yet.
              </p>
            )}
            {activities.map((a) => (
              <div key={a.id} className="border-l-2 border-outline-variant pl-3">
                <div className="flex items-center gap-2">
                  <StatusPill tone={a.kind === "stage_change" ? "primary" : "neutral"}>
                    {ACTIVITY_LABEL[a.kind] ?? a.kind}
                  </StatusPill>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                    {new Date(a.createdAt).toLocaleString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                  {a.createdByName && (
                    <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                      · {a.createdByName}
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[13px] text-on-surface">{a.content}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}
CRMLEADDETAIL_EOF

echo "==> Step 4/4: writing the schema migration"
mkdir -p supabase
cat > supabase/schema-phase6-crm-upgrades.sql << 'SCHEMA_EOF'
-- Sanestix OS — Phase 6: CRM production upgrades.
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is ADD COLUMN IF NOT EXISTS.
--
-- Adds:
--   crm_leads.lost_reason — captured when a lead is marked "lost", so the
--   CRM pipeline page can show a real win/loss breakdown instead of just a
--   raw lost count.

alter table public.crm_leads add column if not exists lost_reason text;
SCHEMA_EOF

echo ""
echo "Done writing files."
echo ""
echo "IMPORTANT — one manual step: run supabase/schema-phase6-crm-upgrades.sql"
echo "in your Supabase project's SQL editor (adds the lost_reason column)."
echo "The app will build and run without it, but lost-reason tracking won't"
echo "persist until that column exists."
echo ""
echo "Then rebuild and restart:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
