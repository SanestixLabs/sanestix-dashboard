"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { RefreshCw, AlertTriangle, ArrowLeft } from "lucide-react";

export default function FinanceError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Finance module error:", error);
  }, [error]);

  const hint = useMemo(() => {
    const message = error.message ?? "";

    if (/relation .* does not exist/i.test(message) || /does not exist/i.test(message)) {
      return "This table hasn't been created in Supabase yet. Run supabase/schema.sql and supabase/schema-phase2-registers.sql (in that order) in the Supabase SQL editor, then reload.";
    }

    if (/permission denied|row-level security|rls/i.test(message)) {
      return "Row Level Security is blocking this query. Confirm you're signed in and that the table's RLS policies grant access to the authenticated role.";
    }

    if (/fetch failed|network|ENOTFOUND|ECONNREFUSED/i.test(message)) {
      return "Couldn't reach Supabase. Check NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY in .env and that the Supabase project is active.";
    }

    return "Check the Supabase logs (Project → Logs → API) for the underlying query error.";
  }, [error.message]);

  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="w-full max-w-lg border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-error">
          <AlertTriangle size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">This finance page couldn&apos;t load</h1>
        </div>

        <p className="mt-3 font-mono-data text-[12px] text-on-surface-variant break-words">
          {error.message || "Unknown error"}
        </p>

        <div className="mt-4 border-l-2 border-warning/60 bg-warning-tint px-3 py-2">
          <p className="text-[12px] text-on-surface-variant">{hint}</p>
        </div>

        <div className="mt-5 flex flex-wrap gap-3">
          <button
            onClick={reset}
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <RefreshCw size={14} />
            Try again
          </button>
          <Link
            href="/finance"
            className="inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
          >
            <ArrowLeft size={14} />
            Back to Overview
          </Link>
        </div>
      </div>
    </div>
  );
}
