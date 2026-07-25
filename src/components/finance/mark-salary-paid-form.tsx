"use client";

import type { Employee } from "@/lib/types";

export function MarkSalaryPaidForm({
  employees,
  action,
}: {
  employees: Employee[];
  action: (formData: FormData) => void;
}) {
  const currentPeriod = new Date().toISOString().slice(0, 7); // "YYYY-MM"

  return (
    <form action={action} className="mt-4 space-y-3" encType="multipart/form-data">
      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Employee
        </label>
        <select
          name="employeeId"
          required
          defaultValue=""
          onChange={(e) => {
            const opt = e.currentTarget.selectedOptions[0];
            const salary = opt?.dataset.salary;
            const form = e.currentTarget.form;
            const amountInput = form?.elements.namedItem("amount") as HTMLInputElement | null;
            if (amountInput && salary && !amountInput.value) {
              amountInput.value = salary;
            }
          }}
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
        >
          <option value="" disabled>
            Select employee
          </option>
          {employees.map((e) => (
            <option key={e.id} value={e.id} data-salary={e.salary ?? ""}>
              {e.fullName}
              {e.salary !== null ? ` — ${e.salary.toLocaleString()} PKR` : ""}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Amount paid (PKR)
        </label>
        <input
          type="number"
          name="amount"
          step="1"
          min="1"
          required
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
          placeholder="0"
        />
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Pay period (month)
        </label>
        <input
          type="month"
          name="payPeriod"
          required
          defaultValue={currentPeriod}
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
        />
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Payment proof (photo)
        </label>
        <input
          type="file"
          name="proof"
          accept="image/*"
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] file:mr-3 file:border-0 file:bg-surface-container-high file:px-3 file:py-1.5 file:font-mono-data file:text-[11px] file:uppercase file:tracking-wider focus:border-primary focus:outline-none"
        />
        <p className="mt-1 text-[11px] text-on-surface-variant/70">
          Optional — screenshot or photo of the bank transfer/receipt. Max 5MB.
        </p>
      </div>

      <div>
        <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Notes
        </label>
        <input
          type="text"
          name="notes"
          className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
          placeholder="Optional"
        />
      </div>

      <button
        type="submit"
        className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
      >
        Mark salary paid
      </button>
    </form>
  );
}
