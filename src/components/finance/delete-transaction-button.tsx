"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";
import { deleteTransaction } from "@/app/(dashboard)/finance/actions";

export function DeleteTransactionButton({
  transactionId,
  redirectTo,
}: {
  transactionId: string;
  redirectTo: string;
}) {
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        type="button"
        onClick={() => setConfirming(true)}
        aria-label="Delete transaction"
        title="Delete transaction"
        className="inline-flex items-center justify-center rounded-[2px] p-1.5 text-on-surface-variant transition hover:bg-error-tint hover:text-error"
      >
        <Trash2 size={14} />
      </button>
    );
  }

  return (
    <form action={deleteTransaction} className="flex items-center justify-end gap-1.5">
      <input type="hidden" name="transactionId" value={transactionId} />
      <input type="hidden" name="redirectTo" value={redirectTo} />
      <input
        type="password"
        name="password"
        required
        autoFocus
        placeholder="Your password"
        className="w-32 border border-error/40 bg-background px-2 py-1 font-mono-data text-[11px] text-on-surface focus:border-error focus:outline-none"
      />
      <button
        type="submit"
        className="bg-error px-2 py-1.5 text-[10px] font-mono-data uppercase tracking-wider text-white transition hover:brightness-110"
      >
        Confirm
      </button>
      <button
        type="button"
        onClick={() => setConfirming(false)}
        aria-label="Cancel delete"
        title="Cancel"
        className="inline-flex items-center justify-center rounded-[2px] p-1 text-on-surface-variant transition hover:text-on-surface"
      >
        <X size={14} />
      </button>
    </form>
  );
}
