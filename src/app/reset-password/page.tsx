import { updatePassword } from "@/app/auth/actions";

export default async function ResetPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <div className="mb-1 font-mono-data text-[11px] uppercase tracking-wider text-primary">
            Sanestix OS
          </div>
          <h1 className="text-[24px] font-bold tracking-tight text-on-surface">Set a new password</h1>
        </div>

        <form action={updatePassword} className="hairline space-y-4 border bg-surface p-6">
          {params.error && (
            <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
              {params.error}
            </div>
          )}

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              New password
            </label>
            <input
              type="password"
              name="password"
              required
              minLength={8}
              autoComplete="new-password"
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="••••••••"
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
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Update password
          </button>

          <p className="text-center text-[11px] text-on-surface-variant">
            This link is only valid if you got here from a password reset email. If it&apos;s expired,{" "}
            <a href="/forgot-password" className="text-primary hover:underline">
              request a new one
            </a>
            .
          </p>
        </form>
      </div>
    </div>
  );
}
