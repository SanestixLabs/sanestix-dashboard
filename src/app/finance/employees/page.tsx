import { FinanceRegisterPage } from "@/components/finance/finance-register-page";

export const dynamic = "force-dynamic";

export default function EmployeesPage() {
  return (
    <FinanceRegisterPage
      title="Employees"
      description="Prepare payroll and compensation tracking before salaries, bonuses, commissions, and deductions become regular records."
      examples={[
        "Employee profiles connected to app users",
        "Salary history, bonus, commission, deductions, and payout status",
        "Monthly payroll report and approval workflow",
        "Future link to HR leave balance and performance workspace",
      ]}
    />
  );
}
