#!/usr/bin/env bash
# Sanestix — fix full-reload navigation by giving the dashboard a real,
# persistent Next.js layout instead of each page wrapping its own
# <DashboardShell>. Sidebar/Topbar now mount once; only the page content
# swaps on navigation.
#
# Run from the ROOT of your repo on the VPS. Safe to re-run.
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "ERROR: run this from the repo root (where package.json and src/app live)."
  exit 1
fi

echo "==> Step 1/5: stripping per-page <DashboardShell> wrappers"
python3 - << 'PYEOF'
import re, pathlib, sys

files = [
"src/app/crm/companies/page.tsx",
"src/app/crm/contacts/page.tsx",
"src/app/crm/leads/[id]/page.tsx",
"src/app/crm/page.tsx",
"src/app/crm/tasks/page.tsx",
"src/app/finance/assets/page.tsx",
"src/app/finance/debts/page.tsx",
"src/app/finance/employees/page.tsx",
"src/app/finance/expenses/page.tsx",
"src/app/finance/income/page.tsx",
"src/app/finance/investments/page.tsx",
"src/app/finance/invoices/generator/page.tsx",
"src/app/finance/invoices/page.tsx",
"src/app/finance/loans/page.tsx",
"src/app/finance/page.tsx",
"src/app/finance/profit-split/page.tsx",
"src/app/finance/reimbursements/page.tsx",
"src/app/finance/reports/page.tsx",
"src/app/finance/subscriptions/page.tsx",
"src/app/finance/transactions/page.tsx",
"src/app/finance/vendors/page.tsx",
"src/app/help/page.tsx",
"src/app/page.tsx",
"src/app/projects/[id]/page.tsx",
"src/app/projects/page.tsx",
"src/app/reports/page.tsx",
"src/app/search/page.tsx",
"src/app/settings/page.tsx",
]

dynamic_crumbs = {
    "src/app/projects/[id]/page.tsx": '["Sanestix OS", "Projects", project.name]',
    "src/app/crm/leads/[id]/page.tsx": '["Sanestix OS", "CRM", lead.title]',
}

import_re = re.compile(r'^import \{ DashboardShell \} from "@/components/layout/dashboard-shell";\n', re.M)
open_re = re.compile(r'^( {4})<DashboardShell breadcrumb=\{(\[[^\n]*\])\}>\n', re.M)
close_re = re.compile(r'^( {4})</DashboardShell>\n', re.M)

missing = False
for f in files:
    p = pathlib.Path(f)
    if not p.exists():
        # Already moved into the (dashboard) route group by a previous run
        # of this script -> nothing left to do here, this is expected.
        moved = pathlib.Path(f.replace("src/app/", 'src/app/(dashboard)/', 1))
        if moved.exists():
            print("SKIP (already migrated & moved):", f)
        else:
            print("MISSING FILE (not found at old or new path):", f)
            missing = True
        continue

    s = p.read_text()
    if not import_re.search(s):
        print("SKIP (no DashboardShell import, already migrated?):", f)
        continue

    s2 = import_re.sub('', s, count=1)
    m = open_re.search(s2)
    if not m:
        print("PATTERN NOT FOUND, left untouched:", f)
        missing = True
        continue

    if f in dynamic_crumbs:
        replacement = f'{m.group(1)}<>\n{m.group(1)}<SetBreadcrumb crumbs={{{dynamic_crumbs[f]}}} />\n'
        if 'breadcrumb-context' not in s2 and 'import { Card' in s2:
            s2 = s2.replace(
                'import { Card',
                'import { SetBreadcrumb } from "@/components/layout/breadcrumb-context";\nimport { Card',
                1
            )
    else:
        replacement = f'{m.group(1)}<>\n'

    s3 = open_re.sub(replacement, s2, count=1)
    if not close_re.search(s3):
        print("CLOSE TAG NOT FOUND, left untouched:", f)
        missing = True
        continue
    s4 = close_re.sub(lambda mm: f'{mm.group(1)}</>\n', s3, count=1)
    p.write_text(s4)
    print("OK", f)

if missing:
    sys.exit(1)
PYEOF

echo "==> Step 2/5: moving routes into a (dashboard) route group"
mkdir -p "src/app/(dashboard)"
for d in finance crm projects reports settings help search; do
  if [ -d "src/app/$d" ] && [ ! -d "src/app/(dashboard)/$d" ]; then
    mv "src/app/$d" "src/app/(dashboard)/$d"
  fi
done
if [ -f src/app/page.tsx ] && [ ! -e "src/app/(dashboard)/page.tsx" ]; then
  mv src/app/page.tsx "src/app/(dashboard)/page.tsx"
fi

echo "==> Step 3/5: keeping the Finance password gate outside the shell"
if [ -d "src/app/(dashboard)/finance/verify" ] && [ ! -d src/app/finance/verify ]; then
  mkdir -p src/app/finance
  mv "src/app/(dashboard)/finance/verify" src/app/finance/verify
fi

echo "==> Step 4/5: repointing server-action imports at their new path"
grep -rl '"@/app/finance/actions"' src --include="*.ts" --include="*.tsx" 2>/dev/null \
  | xargs -r sed -i 's#"@/app/finance/actions"#"@/app/(dashboard)/finance/actions"#g'
grep -rl '"@/app/crm/actions"' src --include="*.ts" --include="*.tsx" 2>/dev/null \
  | xargs -r sed -i 's#"@/app/crm/actions"#"@/app/(dashboard)/crm/actions"#g'
grep -rl '"@/app/projects/actions"' src --include="*.ts" --include="*.tsx" 2>/dev/null \
  | xargs -r sed -i 's#"@/app/projects/actions"#"@/app/(dashboard)/projects/actions"#g'

echo "==> Step 5/5: writing the shared layout, breadcrumb context, and new Topbar"
mkdir -p "src/app/(dashboard)"
mkdir -p src/components/layout

cat > "src/app/(dashboard)/layout.tsx" << 'LAYOUT_EOF'
import { Sidebar } from "@/components/layout/sidebar";
import { Topbar } from "@/components/layout/topbar";
import { createClient } from "@/lib/supabase/server";
import { InactivityMonitor } from "@/components/auth/inactivity-monitor";
import { BreadcrumbProvider } from "@/components/layout/breadcrumb-context";

// Every authenticated route (Finance, Projects, CRM, Reports, Settings,
// Help, Search, the home dashboard) lives under this route group so Sidebar
// and Topbar mount ONCE and persist across navigations. Previously each
// page wrapped itself in <DashboardShell>, which meant there was no shared
// layout boundary for the App Router to preserve — every click between
// tabs unmounted and remounted the whole shell (sidebar animation reset,
// scroll reset, auth re-fetch), which felt like a full page reload even
// though it technically wasn't one. Moving the shell here fixes that.
export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <BreadcrumbProvider>
      <div className="min-h-screen bg-background">
        <InactivityMonitor />
        <Sidebar userEmail={user?.email} />
        <Topbar userEmail={user?.email} />
        <main className="min-h-screen pt-16 pb-20 lg:ml-[248px] lg:pb-0">
          <div className="space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">{children}</div>
        </main>
      </div>
    </BreadcrumbProvider>
  );
}
LAYOUT_EOF

cat > src/components/layout/breadcrumb-context.tsx << 'BREADCRUMB_EOF'
"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";

type BreadcrumbContextValue = {
  override: string[] | null;
  setOverride: (crumbs: string[] | null) => void;
};

const BreadcrumbContext = createContext<BreadcrumbContextValue | null>(null);

export function BreadcrumbProvider({ children }: { children: React.ReactNode }) {
  const [override, setOverrideState] = useState<string[] | null>(null);
  const setOverride = useCallback((crumbs: string[] | null) => setOverrideState(crumbs), []);

  return (
    <BreadcrumbContext.Provider value={{ override, setOverride }}>
      {children}
    </BreadcrumbContext.Provider>
  );
}

export function useBreadcrumbContext() {
  const ctx = useContext(BreadcrumbContext);
  if (!ctx) {
    throw new Error("useBreadcrumbContext must be used within a BreadcrumbProvider");
  }
  return ctx;
}

/**
 * Drop this into a page whose breadcrumb tail depends on data fetched at
 * request time (a project name, a lead title) that the static path→label
 * map in Topbar can't know in advance. Renders nothing; it just registers
 * the crumb for the Topbar to render, and clears it on unmount so the next
 * page picked via client-side navigation doesn't inherit a stale trail.
 */
export function SetBreadcrumb({ crumbs }: { crumbs: string[] }) {
  const { setOverride } = useBreadcrumbContext();
  const key = crumbs.join("\u241F");

  useEffect(() => {
    setOverride(crumbs);
    return () => setOverride(null);
    // Re-run only when the actual crumb text changes, not on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return null;
}
BREADCRUMB_EOF

cat > src/components/layout/topbar.tsx << 'TOPBAR_EOF'
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
TOPBAR_EOF

echo ""
echo "Done. Rebuild and restart:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
echo ""
echo "Then click between Finance / Projects / CRM / Reports — navigation"
echo "should now swap content in place instead of flashing/reloading."
