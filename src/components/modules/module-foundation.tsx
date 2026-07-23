import { ArrowRight, CheckCircle2 } from "lucide-react";
import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";

type ModuleFoundationProps = {
  title: string;
  eyebrow: string;
  description: string;
  breadcrumb: string[];
  readyItems: string[];
  nextItems: string[];
};

export function ModuleFoundation({
  title,
  eyebrow,
  description,
  breadcrumb,
  readyItems,
  nextItems,
}: ModuleFoundationProps) {
  return (
    <DashboardShell breadcrumb={breadcrumb}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="font-mono-data text-[11px] uppercase tracking-wider text-primary">
            {eyebrow}
          </p>
          <h1 className="mt-1 text-[28px] font-bold tracking-tight text-on-surface">
            {title}
          </h1>
          <p className="mt-2 max-w-2xl text-[13px] leading-6 text-on-surface-variant">
            {description}
          </p>
        </div>
        <Link
          href="/finance"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          Use live finance
          <ArrowRight size={14} />
        </Link>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-6">
          <CardTitle>Available Now</CardTitle>
          <CardDescription>Stable pieces already in this deployed system.</CardDescription>
          <div className="mt-4 space-y-3">
            {readyItems.map((item) => (
              <div key={item} className="flex items-start gap-3 text-[13px] text-on-surface">
                <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-success" />
                <span>{item}</span>
              </div>
            ))}
          </div>
        </Card>

        <Card className="p-6">
          <CardTitle>Build Next</CardTitle>
          <CardDescription>Planned work for a complete long-term OS.</CardDescription>
          <div className="mt-4 divide-y divide-outline-variant">
            {nextItems.map((item, index) => (
              <div key={item} className="flex gap-3 py-3 text-[13px]">
                <span className="font-mono-data text-[11px] text-on-surface-variant">
                  {String(index + 1).padStart(2, "0")}
                </span>
                <span className="text-on-surface">{item}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
