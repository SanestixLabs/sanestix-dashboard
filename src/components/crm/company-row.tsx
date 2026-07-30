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
