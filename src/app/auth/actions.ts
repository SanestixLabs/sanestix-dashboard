"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    redirect(`/login?error=${encodeURIComponent(error.message)}`);
  }

  redirect(redirectTo || "/");
}

export async function signUp(formData: FormData) {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  const fullName = String(formData.get("fullName") ?? "");

  const supabase = await createClient();
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName },
      emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/confirm`,
    },
  });

  if (error) {
    redirect(`/signup?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/login?message=Check your email to confirm your account");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  const cookieStore = await cookies();
  cookieStore.delete("finance_verified");
  redirect("/login");
}

// Same as signOut(), but triggered client-side by InactivityMonitor after a
// period of no mouse/keyboard/touch/scroll activity, so the user lands back
// on /login with an explanation instead of a bare form.
export async function signOutInactive() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  const cookieStore = await cookies();
  cookieStore.delete("finance_verified");
  redirect(`/login?message=${encodeURIComponent("You were signed out due to inactivity.")}`);
}

// Step 1 of "forgot password": email a recovery link. Always redirects to the
// same "check your email" message regardless of whether the address exists,
// so this can't be used to enumerate registered emails.
export async function requestPasswordReset(formData: FormData) {
  const email = String(formData.get("email") ?? "");

  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email, {
    // Reuses the existing OTP-verification route. It verifies the recovery
    // token (which logs the user in with a temporary session) and then
    // forwards them to /reset-password to actually set a new password.
    redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/confirm?next=/reset-password`,
  });

  redirect("/forgot-password?message=If an account exists for that email, a reset link is on its way.");
}

// Step 2 of "forgot password": called from /reset-password once the user has
// landed there via the recovery link, so they already have a valid (if
// temporary) Supabase session. Also reachable while normally logged in as a
// plain "change my password".
export async function updatePassword(formData: FormData) {
  const password = String(formData.get("password") ?? "");
  const confirmPassword = String(formData.get("confirmPassword") ?? "");

  if (password.length < 8) {
    redirect("/reset-password?error=Password must be at least 8 characters");
  }
  if (password !== confirmPassword) {
    redirect("/reset-password?error=Passwords do not match");
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({ password });

  if (error) {
    redirect(`/reset-password?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/login?message=Password updated. Please sign in.");
}

// Profile setting: change the logged-in user's email. Supabase sends a
// confirmation link to the new address (and, if "secure email change" is on
// in your Supabase project, one to the old address too) before the change
// takes effect — handled by the same /auth/confirm route.
export async function updateEmail(formData: FormData) {
  const email = String(formData.get("email") ?? "");

  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser(
    { email },
    { emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/confirm?next=/settings` }
  );

  if (error) {
    redirect(`/settings?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/settings?message=Check your new email address to confirm the change.");
}

// Profile setting: change password while already logged in (as opposed to
// via the forgot-password recovery flow). Requires the current password to
// be re-entered so a hijacked/left-open session can't silently lock out the
// real owner.
export async function changePassword(formData: FormData) {
  const currentPassword = String(formData.get("currentPassword") ?? "");
  const newPassword = String(formData.get("newPassword") ?? "");
  const confirmPassword = String(formData.get("confirmPassword") ?? "");

  if (newPassword.length < 8) {
    redirect("/settings?error=New password must be at least 8 characters");
  }
  if (newPassword !== confirmPassword) {
    redirect("/settings?error=New passwords do not match");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect("/settings?error=Could not verify current session");
  }

  // Re-authenticate with the current password before allowing the change.
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: currentPassword,
  });
  if (signInError) {
    redirect("/settings?error=Current password is incorrect");
  }

  const { error } = await supabase.auth.updateUser({ password: newPassword });
  if (error) {
    redirect(`/settings?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/settings?message=Password changed successfully.");
}
