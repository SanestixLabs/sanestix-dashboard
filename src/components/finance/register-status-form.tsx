"use client";

import { StatusPill } from "@/components/ui/status-pill";

type Tone = "primary" | "success" | "warning" | "error" | "neutral";

export function RegisterStatusForm({
  idFieldName,
  idValue,
  status,
  tone,
  options,
  action,
  extraFields,
}: {
  idFieldName: string;
  idValue: string;
  status: string;
  tone: Tone;
  options: { value: string; label: string }[];
  action: (formData: FormData) => void;
  extraFields?: Record<string, string>;
}) {
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name={idFieldName} value={idValue} />
      {extraFields &&
        Object.entries(extraFields).map(([name, value]) => (
          <input key={name} type="hidden" name={name} value={value} />
        ))}
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
