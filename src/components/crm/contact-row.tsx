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
