import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

/**
 * Shared "re-enter your password to delete this" guard, used by every
 * destructive server action across Finance, CRM, and Projects. Redirects
 * (throws) on any failure; only returns when the password was correct.
 */
export async function confirmPasswordOrRedirect(
  password: string,
  redirectTo: string
): Promise<{ supabase: Awaited<ReturnType<typeof createClient>>; user: { id: string; email: string } }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete this")}`);
  }
  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Nothing was deleted.")}`);
  }

  return { supabase, user: { id: user.id, email: user.email } };
}
