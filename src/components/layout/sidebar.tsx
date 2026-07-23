"use client";

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
} from "lucide-react";
import { cn } from "@/lib/utils";
import { signOut } from "@/app/auth/actions";

const NAV_ITEMS = [
  { label: "Dashboard", icon: LayoutDashboard, href: "/" },
  { label: "Finance", icon: Wallet, href: "/finance" },
  { label: "Projects", icon: Kanban, href: "/projects" },
  { label: "CRM", icon: Users, href: "/crm" },
  { label: "Reports", icon: FileText, href: "/reports" },
  { label: "Settings", icon: Settings, href: "/settings" },
];

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

        <nav className="flex-1 space-y-1 px-3">
          {NAV_ITEMS.map(({ label, icon: Icon, href }) => {
            const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
            return (
              <Link
                key={label}
                href={href}
                className={cn(
                  "group flex w-full items-center gap-3 px-3 py-2.5 text-left text-[13px] font-medium transition-colors",
                  active
                    ? "border-l-2 border-primary bg-primary/[0.06] text-primary"
                    : "border-l-2 border-transparent text-on-surface-variant hover:text-on-surface"
                )}
              >
                <Icon size={17} strokeWidth={2} />
                <span>{label}</span>
              </Link>
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
          <form action={signOut}>
            <button
              type="submit"
              className="flex w-full items-center gap-3 px-3 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface-variant hover:text-error"
            >
              <LogOut size={15} />
              Sign out
            </button>
          </form>

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

      <nav className="fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t border-outline-variant bg-surface/95 px-2 py-1.5 backdrop-blur lg:hidden">
        {NAV_ITEMS.slice(0, 5).map(({ label, icon: Icon, href }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          return (
            <Link
              key={label}
              href={href}
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
