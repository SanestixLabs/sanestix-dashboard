import { FinanceRegisterPage } from "@/components/finance/finance-register-page";

export const dynamic = "force-dynamic";

export default function DebtsPage() {
  return (
    <FinanceRegisterPage
      title="Debts & Liabilities"
      description="Track all non-founder liabilities separately from founder reimbursements so the company balance sheet stays clean."
      examples={[
        "Vendor payables, taxes payable, credit cards, and external loans",
        "Fields: counterparty, principal, due date, paid amount, remaining balance",
        "Payment schedule and overdue alerts",
        "Separate from founder investment and reimbursement ledgers",
      ]}
    />
  );
}
