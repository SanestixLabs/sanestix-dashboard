import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Server-side Supabase instance — for use in Server Components, Route
// Handlers, and Server Actions. Reads/writes the auth cookie so the
// user's session is available on the server for RLS-scoped queries.
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // setAll called from a Server Component (no response to write to).
            // Safe to ignore as long as middleware.ts also refreshes sessions.
          }
        },
      },
    }
  );
}
