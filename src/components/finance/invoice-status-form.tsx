"use client";

import { StatusPill } from "@/components/ui/status-pill";
import type { InvoiceStatus } from "@/lib/types";

const STATUS_TONE: Record<InvoiceStatus, "success" | "warning" | "error"> = {
  paid: "success",
  outstanding: "warning",
  overdue: "error",
};

export function InvoiceStatusForm({
  invoiceId,
  status,
  action,
}: {
  invoiceId: string;
  status: InvoiceStatus;
  action: (formData: FormData) => void;
}) {
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name="invoiceId" value={invoiceId} />
      <StatusPill tone={STATUS_TONE[status]}>{status}</StatusPill>
      <select
        name="status"
        defaultValue={status}
        onChange={(e) => e.currentTarget.form?.requestSubmit()}
        className="border border-outline-variant bg-background px-1.5 py-1 font-mono-data text-[10px] uppercase tracking-wider focus:border-primary focus:outline-none"
      >
        <option value="outstanding">Outstanding</option>
        <option value="paid">Paid</option>
        <option value="overdue">Overdue</option>
      </select>
    </form>
  );
}
