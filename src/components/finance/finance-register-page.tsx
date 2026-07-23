import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";

export function FinanceRegisterPage({
  title,
  description,
  examples,
}: {
  title: string;
  description: string;
  examples: string[];
}) {
  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", title]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">{title}</h1>
          <p className="mt-1 max-w-2xl text-[13px] leading-6 text-on-surface-variant">
            {description}
          </p>
        </div>
        <Link
          href="/finance/transactions"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add finance entry
        </Link>
      </div>

      <FinanceTabs />

      <Card className="p-6">
        <CardTitle>Register Structure</CardTitle>
        <CardDescription>
          This register is prepared for long-term tracking. Add dedicated Supabase tables when
          the company starts recording these items regularly.
        </CardDescription>
        <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
          {examples.map((example) => (
            <div
              key={example}
              className="border border-outline-variant bg-background px-4 py-3 text-[13px] text-on-surface"
            >
              {example}
            </div>
          ))}
        </div>
      </Card>
    </DashboardShell>
  );
}
