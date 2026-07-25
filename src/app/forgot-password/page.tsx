import Link from "next/link";
import { requestPasswordReset } from "@/app/auth/actions";

export default async function ForgotPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <div className="mb-1 font-mono-data text-[11px] uppercase tracking-wider text-primary">
            Sanestix OS
          </div>
          <h1 className="text-[24px] font-bold tracking-tight text-on-surface">Reset password</h1>
          <p className="mt-2 text-[13px] text-on-surface-variant">
            Enter your account email and we&apos;ll send you a link to reset your password.
          </p>
        </div>

        <form action={requestPasswordReset} className="hairline space-y-4 border bg-surface p-6">
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

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Email
            </label>
            <input
              type="email"
              name="email"
              required
              autoComplete="email"
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="you@sanestix.com"
            />
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Send reset link
          </button>
        </form>

        <p className="mt-4 text-center text-[13px] text-on-surface-variant">
          Remembered it?{" "}
          <Link href="/login" className="text-primary hover:underline">
            Back to sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
