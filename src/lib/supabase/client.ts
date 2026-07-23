import { createBrowserClient } from "@supabase/ssr";

// Client-side Supabase instance — safe to use in "use client" components.
// Uses the public URL + anon key only (never the service role key).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
