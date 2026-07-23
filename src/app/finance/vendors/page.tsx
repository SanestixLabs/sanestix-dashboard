import { FinanceRegisterPage } from "@/components/finance/finance-register-page";

export const dynamic = "force-dynamic";

export default function VendorsPage() {
  return (
    <FinanceRegisterPage
      title="Vendors"
      description="Track recurring suppliers, service providers, payment terms, contact people, tax records, and linked expenses."
      examples={[
        "Software vendors: hosting, email, SEMrush, CapCut Pro, Voxiquo",
        "Professional services: lawyer, registration support, accounting",
        "Vendor fields: name, category, owner, renewal date, payment terms, status",
        "Link each expense entry back to a vendor once vendor tables are enabled",
      ]}
    />
  );
}
