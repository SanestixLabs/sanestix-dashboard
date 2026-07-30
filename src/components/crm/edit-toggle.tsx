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
