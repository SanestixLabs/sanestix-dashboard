import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Runs on every request. Refreshes the Supabase auth cookie (required with
// @supabase/ssr) and redirects unauthenticated users away from the app,
// and authenticated users away from the login/signup pages.
//
// Named `proxy` (not `middleware`) — Next.js 16.2+ silently ignores a file
// named middleware.ts, so this file MUST be proxy.ts with this export name
// or auth protection stops running with no error at all.
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // This runs on literally every request. If Supabase is briefly
  // unreachable (paused free-tier project, DNS blip, expired/rotated key),
  // getUser() throws — and an uncaught throw in middleware takes down the
  // ENTIRE site with a raw platform error page (no custom error.tsx, no
  // finance/error.tsx hint), not just the page being visited. That matches
  // "this page and many others are broken" far better than a single bad
  // query would. Fail open here (treat as logged-out) so a Supabase hiccup
  // degrades to "please log in" instead of a site-wide outage.
  let user = null;
  try {
    const {
      data: { user: authedUser },
    } = await supabase.auth.getUser();
    user = authedUser;
  } catch (error) {
    console.error("proxy: supabase.auth.getUser() failed", error);
  }

  const path = request.nextUrl.pathname;
  const isAuthRoute = path.startsWith("/login") || path.startsWith("/signup");

  if (!user && !isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("redirectTo", path);
    return NextResponse.redirect(url);
  }

  if (user && isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    url.searchParams.delete("redirectTo");
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: [
    // Run on everything except static assets, images, and favicon.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
