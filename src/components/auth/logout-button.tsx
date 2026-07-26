"use client";

import type { ReactNode } from "react";
import { signOut } from "@/app/auth/actions";

// Thin wrapper around the existing signOut server action that adds a
// confirmation prompt first. Kept as a real <form action={signOut}> (not a
// plain onClick) so it still works as a progressively-enhanced form; the
// onSubmit handler just vetoes the submit if the user backs out.
export function LogoutButton({
  className,
  title,
  children,
}: {
  className?: string;
  title?: string;
  children: ReactNode;
}) {
  return (
    <form
      action={signOut}
      onSubmit={(e) => {
        if (!window.confirm("Sign out of Sanestix OS?")) {
          e.preventDefault();
        }
      }}
    >
      <button type="submit" title={title} className={className}>
        {children}
      </button>
    </form>
  );
}
