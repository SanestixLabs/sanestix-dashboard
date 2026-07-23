import { ShieldCheck, UserRoundCog } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Settings"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Settings</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Account, access, and system configuration for the internal dashboard.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-6">
          <div className="flex items-center gap-3">
            <UserRoundCog size={18} className="text-primary" />
            <CardTitle>Account</CardTitle>
          </div>
          <CardDescription>Current authenticated session.</CardDescription>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex justify-between gap-4 border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">Email</span>
              <span className="break-all text-right font-mono-data">{user?.email ?? "Unknown"}</span>
            </div>
            <div className="flex justify-between gap-4 border-b border-outline-variant pb-3">
              <span className="text-on-surface-variant">User ID</span>
              <span className="break-all text-right font-mono-data">{user?.id ?? "Unknown"}</span>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <div className="flex items-center gap-3">
            <ShieldCheck size={18} className="text-success" />
            <CardTitle>Access Model</CardTitle>
          </div>
          <CardDescription>What is active today and what should be tightened next.</CardDescription>
          <div className="mt-4 space-y-3 text-[13px] text-on-surface">
            <p>Supabase Auth protects all dashboard pages and refreshes sessions through the Next.js proxy.</p>
            <p>Finance tables use Row Level Security for authenticated users. The next production hardening step is role-based write access for admins and finance managers.</p>
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
