import { Sidebar } from "./sidebar";
import { Topbar } from "./topbar";
import { createClient } from "@/lib/supabase/server";

export async function DashboardShell({
  breadcrumb,
  children,
}: {
  breadcrumb: string[];
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="min-h-screen bg-background">
      <Sidebar userEmail={user?.email} />
      <Topbar breadcrumb={breadcrumb} userEmail={user?.email} />
      <main className="min-h-screen pt-16 pb-20 lg:ml-[248px] lg:pb-0">
        <div className="space-y-6 px-4 py-5 sm:px-6 lg:px-8 lg:py-8">{children}</div>
      </main>
    </div>
  );
}
