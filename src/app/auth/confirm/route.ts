import { type EmailOtpType } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

// Handles the link Supabase sends in confirmation / magic-link / password-reset
// emails. The email template must point here with token_hash + type params
// (see Step 2 in setup notes) rather than relying on Supabase's own hosted
// redirect, which is what was 404-ing before.
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const token_hash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = searchParams.get("next") ?? "/";

  if (token_hash && type) {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({ type, token_hash });

    if (!error) {
      redirect(next);
    }

    redirect(`/login?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/login?error=Invalid or expired confirmation link");
}
