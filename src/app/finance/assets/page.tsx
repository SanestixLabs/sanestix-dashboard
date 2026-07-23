import { FinanceRegisterPage } from "@/components/finance/finance-register-page";

export const dynamic = "force-dynamic";

export default function AssetsPage() {
  return (
    <FinanceRegisterPage
      title="Assets"
      description="Track company-owned equipment and high-value purchases separately from normal operating expenses."
      examples={[
        "Equipment: microphone, laptops, phones, cameras, office devices",
        "Fields: asset name, purchase date, cost, owner, condition, serial number",
        "Depreciation and disposal notes for audit history",
        "Link purchase expense to the asset record",
      ]}
    />
  );
}
