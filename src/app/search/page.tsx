import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils";
import { getInvoices, getLoanLedger, getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const query = ((await searchParams).q ?? "").trim().toLowerCase();
  const [transactions, invoices, loans] = await Promise.all([
    getTransactions(),
    getInvoices(),
    getLoanLedger(),
  ]);

  const transactionMatches = transactions.filter((transaction) =>
    [transaction.category, transaction.note, transaction.kind, transaction.createdByName]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query))
  );
  const invoiceMatches = invoices.filter((invoice) =>
    [invoice.clientName, invoice.status, invoice.createdByName]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query))
  );
  const loanMatches = loans.filter((entry) =>
    [entry.founderName, entry.description, entry.direction]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query))
  );

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Search"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Search</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Results for <span className="font-mono-data text-on-surface">{query || "everything"}</span>
        </p>
      </div>

      <Card className="p-6">
        <CardTitle>Finance Results</CardTitle>
        <CardDescription>Transactions, invoices, and founder ledger matches.</CardDescription>
        <div className="mt-4 divide-y divide-outline-variant">
          {[...transactionMatches, ...invoiceMatches, ...loanMatches].length === 0 && (
            <p className="py-6 text-[13px] text-on-surface-variant">No matching records found.</p>
          )}
          {transactionMatches.map((transaction) => (
            <Link
              key={transaction.id}
              href="/finance/transactions"
              className="block py-3 text-[13px] hover:text-primary"
            >
              {transaction.occurredOn} - {transaction.kind} - {transaction.note ?? transaction.category} -{" "}
              {formatCurrency(transaction.amount)}
            </Link>
          ))}
          {invoiceMatches.map((invoice) => (
            <Link key={invoice.id} href="/finance/invoices" className="block py-3 text-[13px] hover:text-primary">
              {invoice.clientName} invoice - {invoice.status} - {formatCurrency(invoice.amount)}
            </Link>
          ))}
          {loanMatches.map((entry) => (
            <Link key={entry.id} href="/finance/loans" className="block py-3 text-[13px] hover:text-primary">
              {entry.founderName ?? "Founder"} - {entry.description} - {formatCurrency(entry.amount)}
            </Link>
          ))}
        </div>
      </Card>
    </DashboardShell>
  );
}
