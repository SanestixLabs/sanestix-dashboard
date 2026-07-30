import { KeyRound, Mail, ShieldCheck, UserRoundCog } from "lucide-react";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";
import { changePassword, updateEmail } from "@/app/auth/actions";

export const dynamic = "force-dynamic";

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const params = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Settings</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Account, access, and system configuration for the internal dashboard.
        </p>
      </div>

      {params.message && (
        <div className="border border-primary/30 bg-primary-tint px-3 py-2 text-[12px] text-primary">
          {params.message}
        </div>
      )}
      {params.error && (
        <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
          {params.error}
        </div>
      )}

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

        <Card className="p-6">
          <div className="flex items-center gap-3">
            <Mail size={18} className="text-primary" />
            <CardTitle>Change Email</CardTitle>
          </div>
          <CardDescription>
            You&apos;ll get a confirmation link at the new address before the change takes effect.
          </CardDescription>
          <form action={updateEmail} className="mt-4 space-y-3">
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                New email
              </label>
              <input
                type="email"
                name="email"
                required
                defaultValue={user?.email ?? ""}
                autoComplete="email"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="bg-primary px-4 py-2 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Update email
            </button>
          </form>
        </Card>

        <Card className="p-6">
          <div className="flex items-center gap-3">
            <KeyRound size={18} className="text-primary" />
            <CardTitle>Change Password</CardTitle>
          </div>
          <CardDescription>Re-enter your current password to confirm the change.</CardDescription>
          <form action={changePassword} className="mt-4 space-y-3">
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Current password
              </label>
              <input
                type="password"
                name="currentPassword"
                required
                autoComplete="current-password"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                New password
              </label>
              <input
                type="password"
                name="newPassword"
                required
                minLength={8}
                autoComplete="new-password"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Confirm new password
              </label>
              <input
                type="password"
                name="confirmPassword"
                required
                minLength={8}
                autoComplete="new-password"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="bg-primary px-4 py-2 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Change password
            </button>
          </form>
        </Card>
      </div>
    </>
  );
}
