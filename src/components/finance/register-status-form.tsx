"use client";

import { StatusPill } from "@/components/ui/status-pill";

type Tone = "success" | "warning" | "error" | "neutral";

export function RegisterStatusForm({
  idFieldName,
  idValue,
  status,
  tone,
  options,
  action,
}: {
  idFieldName: string;
  idValue: string;
  status: string;
  tone: Tone;
  options: { value: string; label: string }[];
  action: (formData: FormData) => void;
}) {
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name={idFieldName} value={idValue} />
      <StatusPill tone={tone}>{status}</StatusPill>
      <select
        name="status"
        defaultValue={status}
        onChange={(e) => e.currentTarget.form?.requestSubmit()}
        className="border border-outline-variant bg-background px-1.5 py-1 font-mono-data text-[10px] uppercase tracking-wider focus:border-primary focus:outline-none"
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </form>
  );
}
