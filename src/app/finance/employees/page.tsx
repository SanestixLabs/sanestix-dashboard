import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { EmployeePayDayForm } from "@/components/finance/employee-payday-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { MarkSalaryPaidForm } from "@/components/finance/mark-salary-paid-form";
import { formatCurrency } from "@/lib/utils";
import { getEmployees, getEmployeePayments } from "@/lib/supabase/queries";
import {
  addEmployee,
  updateEmployeeStatus,
  updateEmployeePayDay,
  deleteEmployee,
  markSalaryPaid,
  deleteEmployeePayment,
} from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function EmployeesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [employees, payments] = await Promise.all([getEmployees(), getEmployeePayments()]);
  const active = employees.filter((e) => e.status === "active");
  const monthlyPayroll = active.reduce((sum, e) => sum + (e.salary ?? 0), 0);

  const lastPaidByEmployee = new Map<string, (typeof payments)[number]>();
  for (const payment of payments) {
    if (!lastPaidByEmployee.has(payment.employeeId)) {
      lastPaidByEmployee.set(payment.employeeId, payment);
    }
  }

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Employees"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Employees</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Payroll and compensation register — salary, role, and status per person.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active employees
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{active.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Monthly payroll
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">
            {formatCurrency(monthlyPayroll)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Inactive
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {employees.length - active.length}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add an employee</CardTitle>
          <CardDescription>Register a new team member.</CardDescription>

          <form action={addEmployee} className="mt-4 space-y-3">
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
                placeholder="e.g. Ayesha Khan"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Role
              </label>
              <input
                type="text"
                name="role"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Video Editor"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Salary (PKR / month)
              </label>
              <input
                type="number"
                name="salary"
                step="1"
                min="0"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Start date
              </label>
              <input
                type="date"
                name="startDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Payday (day of month)
              </label>
              <input
                type="number"
                name="payDay"
                min="1"
                max="31"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. 1 — optional, powers Upcoming Payments"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="active"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add employee
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Employee Register</CardTitle>
          <CardDescription>Newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Role</th>
                  <th className="pb-2 pr-4">Start date</th>
                  <th className="pb-2 pr-4 text-right">Salary</th>
                  <th className="pb-2 pr-4">Payday</th>
                  <th className="pb-2 pr-4">Last paid</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {employees.length === 0 && (
                  <tr>
                    <td colSpan={8} className="py-6 text-center text-on-surface-variant">
                      No employees recorded yet.
                    </td>
                  </tr>
                )}
                {employees.map((e) => (
                  <tr key={e.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{e.fullName}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{e.role ?? "—"}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {e.startDate ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data">
                      {e.salary !== null ? formatCurrency(e.salary) : "—"}
                    </td>
                    <td className="py-2.5 pr-4">
                      <EmployeePayDayForm
                        employeeId={e.id}
                        payDay={e.payDay}
                        action={updateEmployeePayDay}
                      />
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {lastPaidByEmployee.has(e.id) ? (
                        <>
                          {lastPaidByEmployee.get(e.id)!.paidOn}
                          {lastPaidByEmployee.get(e.id)!.proofUrl && (
                            <a
                              href={lastPaidByEmployee.get(e.id)!.proofUrl!}
                              target="_blank"
                              rel="noreferrer"
                              className="ml-1.5 text-primary underline underline-offset-2"
                            >
                              proof
                            </a>
                          )}
                        </>
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="py-2.5 pr-4">
                      <RegisterStatusForm
                        idFieldName="employeeId"
                        idValue={e.id}
                        status={e.status}
                        tone={e.status === "active" ? "success" : "neutral"}
                        options={[
                          { value: "active", label: "Active" },
                          { value: "inactive", label: "Inactive" },
                        ]}
                        action={updateEmployeeStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteEmployee}
                          idFieldName="employeeId"
                          idValue={e.id}
                          redirectTo="/finance/employees"
                          label="employee"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Log a salary payment</CardTitle>
          <CardDescription>
            Mark a payday as paid, optionally attaching a photo of the transfer proof.
          </CardDescription>
          <MarkSalaryPaidForm employees={active} action={markSalaryPaid} />
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Payment History</CardTitle>
          <CardDescription>Every logged salary payment, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Employee</th>
                  <th className="pb-2 pr-4">Pay period</th>
                  <th className="pb-2 pr-4">Paid on</th>
                  <th className="pb-2 pr-4 text-right">Amount</th>
                  <th className="pb-2 pr-4">Proof</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {payments.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No salary payments logged yet.
                    </td>
                  </tr>
                )}
                {payments.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{p.employeeName ?? "—"}</td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {p.payPeriod.slice(0, 7)}
                    </td>
                    <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                      {p.paidOn}
                    </td>
                    <td className="py-2.5 pr-4 text-right font-mono-data text-success">
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="py-2.5 pr-4">
                      {p.proofUrl ? (
                        <a
                          href={p.proofUrl}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-block"
                        >
                          <img
                            src={p.proofUrl}
                            alt={`Payment proof for ${p.employeeName ?? "employee"}`}
                            className="h-9 w-9 rounded-[2px] border border-outline-variant object-cover"
                          />
                        </a>
                      ) : (
                        <span className="text-on-surface-variant/70">—</span>
                      )}
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteEmployeePayment}
                          idFieldName="paymentId"
                          idValue={p.id}
                          redirectTo="/finance/employees"
                          label="payment"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
