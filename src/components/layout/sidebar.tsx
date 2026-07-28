"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Wallet,
  Kanban,
  Users,
  FileText,
  Settings,
  HelpCircle,
  LogOut,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { LogoutButton } from "@/components/auth/logout-button";

const NAV_ITEMS = [
  { label: "Dashboard", icon: LayoutDashboard, href: "/" },
  { label: "Finance", icon: Wallet, href: "/finance" },
  { label: "Projects", icon: Kanban, href: "/projects" },
  { label: "CRM", icon: Users, href: "/crm" },
  { label: "Reports", icon: FileText, href: "/reports" },
  { label: "Settings", icon: Settings, href: "/settings" },
];

// Any nav item with a matching key here gets an expandable submenu (desktop
// flyout + mobile bottom-sheet), same mechanism the old Finance-only bar
// used — just generalized so CRM (and future modules) can have one too.
const SUB_ITEMS: Record<string, { label: string; href: string }[]> = {
  Finance: [
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
  ],
  CRM: [
    { label: "Pipeline", href: "/crm" },
    { label: "Companies", href: "/crm/companies" },
    { label: "Contacts", href: "/crm/contacts" },
    { label: "Tasks", href: "/crm/tasks" },
  ],
};

function getInitials(email?: string) {
  if (!email) return "SU";
  return email
    .split("@")[0]
    .split(/[._-]/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

export function Sidebar({ userEmail }: { userEmail?: string }) {
  const pathname = usePathname();
  const [expandedMenu, setExpandedMenu] = useState<string | null>("Finance");
  const [mobileMenuRequest, setMobileMenuRequest] = useState<string | null>(null);

  const activeItem = NAV_ITEMS.find(({ href }) =>
    href === "/" ? pathname === "/" : pathname.startsWith(href)
  );

  // Derived, not synced: the mobile sheet is only actually open if the
  // requested module is still the one the user is on. Navigating away
  // (via any link, not just this one) closes it automatically without
  // needing a useEffect + setState round-trip.
  const mobileMenuOpen = mobileMenuRequest && activeItem?.label === mobileMenuRequest ? mobileMenuRequest : null;

  return (
    <>
      <aside className="fixed left-0 top-0 z-50 hidden h-full w-[248px] flex-col border-r border-outline-variant bg-surface py-4 lg:flex">
        <div className="mb-8 px-5">
          <span className="text-[20px] font-bold tracking-tight text-primary">
            Sanestix
          </span>
          <p className="mt-1 text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Operations OS
          </p>
        </div>

        <nav className="sidebar-scroll flex-1 space-y-1 overflow-y-auto px-3">
          {NAV_ITEMS.map(({ label, icon: Icon, href }) => {
            const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
            const subItems = SUB_ITEMS[label];
            const hasSubItems = Boolean(subItems);
            const isExpanded = expandedMenu === label;

            return (
              <div key={label}>
                <Link
                  href={href}
                  onClick={(e) => {
                    if (!hasSubItems) return;
                    if (active) {
                      // Already on this module: clicking anywhere on the row
                      // just toggles the submenu open/closed.
                      e.preventDefault();
                      setExpandedMenu((v) => (v === label ? null : label));
                    } else {
                      // Navigating into this module for the first time: open it.
                      setExpandedMenu(label);
                    }
                  }}
                  className={cn(
                    "group flex w-full items-center gap-3 px-3 py-2.5 text-left text-[13px] font-medium transition-all duration-200 ease-out",
                    active
                      ? "border-l-2 border-primary bg-primary/[0.06] text-primary"
                      : "border-l-2 border-transparent text-on-surface-variant hover:translate-x-0.5 hover:border-primary/40 hover:bg-primary/[0.04] hover:text-on-surface"
                  )}
                >
                  <Icon
                    size={17}
                    strokeWidth={2}
                    className="transition-transform duration-200 ease-out group-hover:scale-110"
                  />
                  <span className="flex-1">{label}</span>
                  {hasSubItems && (
                    <ChevronDown
                      size={14}
                      className={cn(
                        "transition-transform duration-200 ease-out",
                        isExpanded && "rotate-180"
                      )}
                    />
                  )}
                </Link>

                {hasSubItems && active && isExpanded && (
                  <div className="ml-[26px] mt-1 space-y-0.5 border-l border-outline-variant pl-3">
                    {subItems.map((tab) => {
                      const tabActive = pathname === tab.href;
                      return (
                        <Link
                          key={tab.href}
                          href={tab.href}
                          className={cn(
                            "block px-2 py-1.5 font-mono-data text-[11px] uppercase tracking-wider transition-all duration-200 ease-out",
                            tabActive
                              ? "text-primary"
                              : "text-on-surface-variant hover:translate-x-0.5 hover:text-on-surface"
                          )}
                        >
                          {tab.label}
                        </Link>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </nav>

        <div className="space-y-1 px-3 pt-4">
          <Link
            href="/help"
            className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
          >
            <HelpCircle size={15} />
            Help
          </Link>
          <LogoutButton className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-error">
            <LogOut size={15} />
            Sign out
          </LogoutButton>

          <div className="mt-3 flex items-center justify-between border border-outline-variant bg-background px-3 py-2.5">
            <div className="flex min-w-0 items-center gap-2.5">
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-primary/20 bg-primary/10 text-[11px] font-semibold text-primary">
                {getInitials(userEmail)}
              </div>
              <div className="flex min-w-0 flex-col leading-none">
                <span className="truncate text-[11px] font-semibold text-on-surface">
                  {userEmail ?? "Signed in"}
                </span>
                <span className="mt-1 text-[9px] uppercase tracking-wider text-on-surface-variant">
                  Team member
                </span>
              </div>
            </div>
          </div>
        </div>
      </aside>

      {/* Mobile submenu drawer — backdrop + sheet, sits above the bottom tab bar */}
      {mobileMenuOpen && SUB_ITEMS[mobileMenuOpen] && (
        <>
          <button
            aria-label={`Close ${mobileMenuOpen} menu`}
            onClick={() => setMobileMenuRequest(null)}
            className="fixed inset-0 z-40 bg-black/40 lg:hidden"
          />
          <div className="fixed inset-x-0 bottom-[56px] z-50 max-h-[60vh] overflow-y-auto border-t border-outline-variant bg-surface pb-2 lg:hidden">
            <div className="flex items-center justify-between px-4 py-3">
              <span className="font-mono-data text-[11px] uppercase tracking-widest text-on-surface-variant/70">
                {mobileMenuOpen}
              </span>
              <button
                onClick={() => setMobileMenuRequest(null)}
                className="text-on-surface-variant"
                aria-label="Close"
              >
                <ChevronUp size={16} />
              </button>
            </div>
            <div className="grid grid-cols-2 gap-1 px-3 pb-3">
              {SUB_ITEMS[mobileMenuOpen].map((tab) => {
                const tabActive = pathname === tab.href;
                return (
                  <Link
                    key={tab.href}
                    href={tab.href}
                    onClick={() => setMobileMenuRequest(null)}
                    className={cn(
                      "border border-outline-variant px-3 py-2.5 text-center font-mono-data text-[11px] uppercase tracking-wider transition-colors",
                      tabActive
                        ? "border-primary/40 bg-primary/[0.06] text-primary"
                        : "text-on-surface-variant hover:text-on-surface"
                    )}
                  >
                    {tab.label}
                  </Link>
                );
              })}
            </div>
          </div>
        </>
      )}

      <nav className="fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t border-outline-variant bg-surface/95 px-2 py-1.5 backdrop-blur lg:hidden">
        {NAV_ITEMS.slice(0, 5).map(({ label, icon: Icon, href }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          const hasSubItems = Boolean(SUB_ITEMS[label]);

          return (
            <Link
              key={label}
              href={href}
              onClick={(e) => {
                if (!hasSubItems) return;
                if (active) {
                  // Already on this module: tap toggles the drawer instead
                  // of re-navigating.
                  e.preventDefault();
                  setMobileMenuRequest((v) => (v === label ? null : label));
                } else {
                  setMobileMenuRequest(label);
                }
              }}
              className={cn(
                "flex min-w-0 flex-col items-center gap-1 px-1 py-2 text-[10px] font-medium transition-colors",
                active ? "text-primary" : "text-on-surface-variant"
              )}
            >
              <Icon size={18} strokeWidth={2} />
              <span className="w-full truncate text-center">{label}</span>
            </Link>
          );
        })}
      </nav>
    </>
  );
}
