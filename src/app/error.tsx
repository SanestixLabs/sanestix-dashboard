"use client";

import { useEffect } from "react";
import { RefreshCw, AlertTriangle } from "lucide-react";

export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Unhandled app error:", error);
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-md border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-error">
          <AlertTriangle size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">Something went wrong</h1>
        </div>
        <p className="mt-2 text-[13px] text-on-surface-variant">
          {error.message || "An unexpected error occurred while loading this page."}
        </p>
        {error.digest && (
          <p className="mt-2 font-mono-data text-[11px] text-on-surface-variant/70">
            Error ref: {error.digest}
          </p>
        )}
        <button
          onClick={reset}
          className="mt-4 inline-flex items-center gap-2 border border-outline-variant bg-background px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-surface transition-colors hover:bg-surface-container-high"
        >
          <RefreshCw size={14} />
          Try again
        </button>
      </div>
    </div>
  );
}
