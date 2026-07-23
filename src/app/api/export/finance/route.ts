import { getInvoices, getLoanLedger, getProfitDistributions, getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function csvRow(values: Array<string | number | null | undefined>) {
  return values.map(csvCell).join(",");
}

export async function GET() {
  const [transactions, invoices, loans, distributions] = await Promise.all([
    getTransactions(),
    getInvoices(),
    getLoanLedger(),
    getProfitDistributions(),
  ]);

  const rows = [
    csvRow(["Section", "Date", "Type", "Name", "Category/Status", "Description", "Amount PKR"]),
    ...transactions.map((transaction) =>
      csvRow([
        "Transactions",
        transaction.occurredOn,
        transaction.kind,
        transaction.category,
        "",
        transaction.note,
        transaction.amount,
      ])
    ),
    ...invoices.map((invoice) =>
      csvRow([
        "Invoices",
        invoice.dueDate,
        "invoice",
        invoice.clientName,
        invoice.status,
        invoice.createdByName,
        invoice.amount,
      ])
    ),
    ...loans.map((entry) =>
      csvRow([
        "Founder Loans",
        entry.occurredOn,
        entry.direction,
        entry.founderName,
        "",
        entry.description,
        entry.amount,
      ])
    ),
    ...distributions.map((distribution) =>
      csvRow([
        "Profit Distributions",
        distribution.periodMonth,
        "distribution",
        "Sanestix",
        `charity ${distribution.charityPct}%`,
        distribution.note,
        distribution.distributableProfit,
      ])
    ),
  ];

  return new Response(rows.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="sanestix-finance-export.csv"',
    },
  });
}
