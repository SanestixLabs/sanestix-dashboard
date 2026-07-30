"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Search, Bell, ChevronRight, LogOut } from "lucide-react";
import { LogoutButton } from "@/components/auth/logout-button";
import { useBreadcrumbContext } from "@/components/layout/breadcrumb-context";

// Static path -> breadcrumb map for every route with a fixed title. Kept
// here (rather than passed down from each page) so Topbar can live in the
// shared (dashboard) layout and survive client-side navigations instead of
// remounting on every route change.
const BREADCRUMB_MAP: Record<string, string[]> = {
  "/": ["Sanestix OS", "Executive Dashboard"],
  "/finance": ["Sanestix OS", "Finance"],
  "/finance/income": ["Sanestix OS", "Finance", "Income"],
  "/finance/expenses": ["Sanestix OS", "Finance", "Expenses"],
  "/finance/transactions": ["Sanestix OS", "Finance", "Transactions"],
  "/finance/invoices": ["Sanestix OS", "Finance", "Invoices"],
  "/finance/invoices/generator": ["Sanestix OS", "Finance", "Invoices", "Generator"],
  "/finance/investments": ["Sanestix OS", "Finance", "Founder Investments"],
  "/finance/reimbursements": ["Sanestix OS", "Finance", "Reimbursements"],
  "/finance/loans": ["Sanestix OS", "Finance", "Loan Ledger"],
  "/finance/profit-split": ["Sanestix OS", "Finance", "Profit Split"],
  "/finance/reports": ["Sanestix OS", "Finance", "Reports"],
  "/finance/vendors": ["Sanestix OS", "Finance", "Vendors"],
  "/finance/employees": ["Sanestix OS", "Finance", "Employees"],
  "/finance/subscriptions": ["Sanestix OS", "Finance", "Subscriptions"],
  "/finance/assets": ["Sanestix OS", "Finance", "Assets"],
  "/finance/debts": ["Sanestix OS", "Finance", "Debts & Liabilities"],
  "/crm": ["Sanestix OS", "CRM"],
  "/crm/companies": ["Sanestix OS", "CRM", "Companies"],
  "/crm/contacts": ["Sanestix OS", "CRM", "Contacts"],
  "/crm/tasks": ["Sanestix OS", "CRM", "Tasks"],
  "/projects": ["Sanestix OS", "Projects"],
  "/reports": ["Sanestix OS", "Reports"],
  "/settings": ["Sanestix OS", "Settings"],
  "/help": ["Sanestix OS", "Help"],
  "/search": ["Sanestix OS", "Search"],
};

// Dynamic routes ([id] segments) fall back to this until the page's own
// <SetBreadcrumb> effect fires with the real name/title.
const PREFIX_FALLBACK: Array<[string, string[]]> = [
  ["/projects/", ["Sanestix OS", "Projects"]],
  ["/crm/leads/", ["Sanestix OS", "CRM"]],
];

function getBreadcrumb(pathname: string): string[] {
  if (BREADCRUMB_MAP[pathname]) return BREADCRUMB_MAP[pathname];
  const prefixMatch = PREFIX_FALLBACK.find(([prefix]) => pathname.startsWith(prefix));
  if (prefixMatch) return prefixMatch[1];
  return ["Sanestix OS"];
}

export function Topbar({ userEmail }: { userEmail?: string }) {
  const pathname = usePathname();
  const { override } = useBreadcrumbContext();
  const breadcrumb = override ?? getBreadcrumb(pathname);

  return (
    <header className="fixed right-0 top-0 z-40 flex h-16 w-full items-center justify-between border-b border-outline-variant bg-surface px-4 lg:w-[calc(100%-248px)] lg:px-8">
      <div className="flex min-w-0 items-center gap-2 text-[13px] text-on-surface-variant">
        {breadcrumb.map((crumb, i) => (
          <span key={`${i}-${crumb}`} className="flex min-w-0 items-center gap-2">
            {i > 0 && <ChevronRight size={13} className="text-outline" />}
            <span
              className={
                i === breadcrumb.length - 1
                  ? "truncate font-medium text-on-surface"
                  : undefined
              }
            >
              {crumb}
            </span>
          </span>
        ))}
      </div>

      <form action="/search" className="hidden flex-1 justify-center px-8 md:flex">
        <div className="group relative w-full max-w-md">
          <Search
            size={15}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant"
          />
          <input
            type="text"
            name="q"
            placeholder="Search invoices, projects, leads..."
            className="w-full border border-outline-variant bg-background py-2 pl-9 pr-3 font-mono-data text-[12px] placeholder:text-on-surface-variant/50 focus:border-primary focus:outline-none"
          />
        </div>
      </form>

      <div className="flex items-center gap-3 lg:gap-5">
        <Link
          href="/reports"
          title="Reports and notifications"
          className="relative p-1 text-on-surface-variant transition-colors hover:text-primary"
        >
          <Bell size={18} />
          <span className="absolute right-0.5 top-0.5 h-1.5 w-1.5 rounded-full bg-primary" />
        </Link>
        <div className="hidden h-6 w-px bg-outline-variant sm:block" />
        {userEmail && (
          <span className="hidden max-w-[180px] truncate font-mono-data text-[11px] text-on-surface-variant xl:inline">
            {userEmail}
          </span>
        )}
        <LogoutButton
          title="Sign out"
          className="p-1 text-on-surface-variant transition-colors hover:text-primary"
        >
          <LogOut size={16} />
        </LogoutButton>
        <Link
          href="/finance/transactions"
          className="hidden bg-primary px-4 py-1.5 text-[11px] font-mono-data font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95 sm:block"
        >
          New Action
        </Link>
      </div>
    </header>
  );
}
