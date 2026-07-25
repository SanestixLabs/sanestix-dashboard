"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";

export function RegisterDeleteButton({
  action,
  idFieldName,
  idValue,
  redirectTo,
  label = "item",
}: {
  action: (formData: FormData) => void;
  idFieldName: string;
  idValue: string;
  redirectTo: string;
  label?: string;
}) {
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        type="button"
        onClick={() => setConfirming(true)}
        aria-label={`Delete ${label}`}
        title={`Delete ${label}`}
        className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-error-tint hover:text-error"
      >
        <Trash2 size={14} />
      </button>
    );
  }

  return (
    <form action={action} className="flex items-center justify-end gap-1.5">
      <input type="hidden" name={idFieldName} value={idValue} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <input
        type="password"
        name="password"
        required
        autoFocus
        placeholder="Password"
        className="w-28 border border-error/40 bg-background px-2 py-1 font-mono-data text-[11px] text-on-surface focus:border-error focus:outline-none"
      />
      <button
        type="submit"
        className="bg-error px-2 py-1.5 text-[10px] font-mono-data uppercase tracking-wider text-white transition hover:brightness-110"
      >
        Confirm
      </button>
      <button
        type="button"
        onClick={() => setConfirming(false)}
        aria-label="Cancel delete"
        title="Cancel"
        className="inline-flex items-center justify-center rounded-[2px] p-1 text-on-surface-variant transition hover:text-on-surface"
      >
        <X size={14} />
      </button>
    </form>
  );
}
