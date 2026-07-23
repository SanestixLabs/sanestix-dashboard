import { ModuleFoundation } from "@/components/modules/module-foundation";

export const dynamic = "force-dynamic";

export default function ReportsPage() {
  return (
    <ModuleFoundation
      title="Reports"
      eyebrow="Phase 2"
      breadcrumb={["Sanestix OS", "Reports"]}
      description="Reports should turn Finance, Projects, and CRM records into monthly summaries, founder-ready exports, and operational review screens."
      readyItems={[
        "Finance overview, transaction ledger, invoices, loans, and profit split are live modules.",
        "Revenue trend and cash-flow charts already consume real finance data.",
        "Export actions have a defined place in the dashboard UI.",
      ]}
      nextItems={[
        "Add date-range filters and CSV export for finance ledgers.",
        "Build monthly revenue, expense, invoice aging, and profit distribution reports.",
        "Add project delivery and CRM conversion reports after those modules move to live data.",
      ]}
    />
  );
}
