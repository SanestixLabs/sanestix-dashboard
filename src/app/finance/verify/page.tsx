import { Lock } from "lucide-react";
import { verifyFinanceAccess } from "@/app/(dashboard)/finance/actions";

export const dynamic = "force-dynamic";

export default async function FinanceVerifyPage({
  searchParams,
}: {
  searchParams: Promise<{ redirectTo?: string; error?: string }>;
}) {
  const params = await searchParams;
  const redirectTo = params.redirectTo || "/finance";

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-sm border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-on-surface">
          <Lock size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">Confirm it&apos;s you</h1>
        </div>
        <p className="mt-2 text-[13px] text-on-surface-variant">
          Enter your account password to open the Finance module. You won&apos;t be asked again
          until you sign in again.
        </p>

        <form action={verifyFinanceAccess} className="mt-4 space-y-3">
          <input type="hidden" name="redirectTo" value={redirectTo} />

          {params.error && (
            <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
              {params.error}
            </div>
          )}

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Password
            </label>
            <input
              type="password"
              name="password"
              required
              autoFocus
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Unlock Finance
          </button>
        </form>
      </div>
    </div>
  );
}
