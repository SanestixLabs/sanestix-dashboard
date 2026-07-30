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
