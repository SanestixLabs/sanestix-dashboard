import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { formatCurrency } from "@/lib/utils";
import { getEmployees } from "@/lib/supabase/queries";
import { addEmployee, updateEmployeeStatus } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function EmployeesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const employees = await getEmployees();
  const active = employees.filter((e) => e.status === "active");
  const monthlyPayroll = active.reduce((sum, e) => sum + (e.salary ?? 0), 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Employees"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Employees</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Payroll and compensation register — salary, role, and status per person.
        </p>
      </div>

      <FinanceTabs />

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
                  <th className="pb-2">Status</th>
                </tr>
              </thead>
              <tbody>
                {employees.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
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
                    <td className="py-2.5">
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
