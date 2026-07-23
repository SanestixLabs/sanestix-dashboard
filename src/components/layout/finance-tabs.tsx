"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const TABS = [
  { label: "Overview", href: "/finance" },
  { label: "Income", href: "/finance/income" },
  { label: "Expenses", href: "/finance/expenses" },
  { label: "Transactions", href: "/finance/transactions" },
  { label: "Invoices", href: "/finance/invoices" },
  { label: "Investments", href: "/finance/investments" },
  { label: "Reimbursements", href: "/finance/reimbursements" },
  { label: "Founder Entry", href: "/finance/loans" },
  { label: "Profit Split", href: "/finance/profit-split" },
  { label: "Reports", href: "/finance/reports" },
  { label: "Vendors", href: "/finance/vendors" },
  { label: "Employees", href: "/finance/employees" },
  { label: "Subscriptions", href: "/finance/subscriptions" },
  { label: "Assets", href: "/finance/assets" },
  { label: "Debts", href: "/finance/debts" },
];

export function FinanceTabs() {
  const pathname = usePathname();

  return (
    <div className="flex gap-1 overflow-x-auto border-b border-outline-variant">
      {TABS.map((tab) => {
        const active = pathname === tab.href;
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={cn(
              "shrink-0 border-b-2 px-4 py-2.5 font-mono-data text-[11px] uppercase tracking-wider transition-colors",
              active
                ? "border-primary text-primary"
                : "border-transparent text-on-surface-variant hover:text-on-surface"
            )}
          >
            {tab.label}
          </Link>
        );
      })}
    </div>
  );
}
