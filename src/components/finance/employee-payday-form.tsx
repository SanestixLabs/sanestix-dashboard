"use client";

export function EmployeePayDayForm({
  employeeId,
  payDay,
  action,
}: {
  employeeId: string;
  payDay: number | null;
  action: (formData: FormData) => void;
}) {
  return (
    <form action={action} className="flex items-center gap-1.5">
      <input type="hidden" name="employeeId" value={employeeId} />
      <input
        type="number"
        name="payDay"
        min={1}
        max={31}
        defaultValue={payDay ?? ""}
        placeholder="—"
        onBlur={(e) => e.currentTarget.form?.requestSubmit()}
        className="w-14 border border-outline-variant bg-background px-1.5 py-1 text-center font-mono-data text-[11px] focus:border-primary focus:outline-none"
      />
      <span className="font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant/70">
        of month
      </span>
    </form>
  );
}
