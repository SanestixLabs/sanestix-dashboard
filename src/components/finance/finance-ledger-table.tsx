import { StatusPill } from "@/components/ui/status-pill";
import { formatCurrency } from "@/lib/utils";
import type { LoanEntry, Transaction } from "@/lib/types";

export function TransactionTable({
  transactions,
  emptyLabel,
}: {
  transactions: Transaction[];
  emptyLabel: string;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[760px] text-left text-[13px]">
        <thead>
          <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            <th className="pb-2 pr-4">Date</th>
            <th className="pb-2 pr-4">Type</th>
            <th className="pb-2 pr-4">Category</th>
            <th className="pb-2 pr-4">Description</th>
            <th className="pb-2 pr-4">Logged by</th>
            <th className="pb-2 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {transactions.length === 0 && (
            <tr>
              <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                {emptyLabel}
              </td>
            </tr>
          )}
          {transactions.map((transaction) => (
            <tr key={transaction.id} className="border-b border-outline-variant/50">
              <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                {transaction.occurredOn}
              </td>
              <td className="py-2.5 pr-4">
                <StatusPill tone={transaction.kind === "revenue" ? "success" : "neutral"}>
                  {transaction.kind === "revenue" ? "Income" : "Expense"}
                </StatusPill>
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.category ?? "-"}
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.note ?? "-"}
              </td>
              <td className="py-2.5 pr-4 text-on-surface-variant">
                {transaction.createdByName ?? "-"}
              </td>
              <td
                className={
                  "py-2.5 text-right font-mono-data " +
                  (transaction.kind === "revenue" ? "text-success" : "text-error")
                }
              >
                {transaction.kind === "revenue" ? "+" : "-"}
                {formatCurrency(transaction.amount)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function LoanTable({
  entries,
  emptyLabel,
}: {
  entries: LoanEntry[];
  emptyLabel: string;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[720px] text-left text-[13px]">
        <thead>
          <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            <th className="pb-2 pr-4">Date</th>
            <th className="pb-2 pr-4">Founder</th>
            <th className="pb-2 pr-4">Description</th>
            <th className="pb-2 pr-4">Direction</th>
            <th className="pb-2 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 && (
            <tr>
              <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                {emptyLabel}
              </td>
            </tr>
          )}
          {entries.map((entry) => (
            <tr key={entry.id} className="border-b border-outline-variant/50">
              <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant">
                {entry.occurredOn}
              </td>
              <td className="py-2.5 pr-4">{entry.founderName ?? "-"}</td>
              <td className="py-2.5 pr-4 text-on-surface-variant">{entry.description}</td>
              <td className="py-2.5 pr-4">
                <StatusPill tone={entry.direction === "loan_in" ? "warning" : "success"}>
                  {entry.direction === "loan_in" ? "Investment" : "Returned"}
                </StatusPill>
              </td>
              <td className="py-2.5 text-right font-mono-data">
                {formatCurrency(entry.amount)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
