import { FinanceRegisterPage } from "@/components/finance/finance-register-page";

export const dynamic = "force-dynamic";

export default function SubscriptionsPage() {
  return (
    <FinanceRegisterPage
      title="Subscriptions"
      description="Central register for monthly and annual tools so renewals, owners, costs, and cancellations do not live in scattered notes."
      examples={[
        "Hosting, email, SEMrush, CapCut Pro, AI tools, and automation tools",
        "Fields: vendor, monthly cost, renewal date, owner, card/account, status",
        "Alerts before renewals and failed payment risk",
        "Roll subscription costs into monthly expense reports",
      ]}
    />
  );
}
