import {
  getInvoices,
  getLoanLedger,
  getProfitDistributions,
  getTransactions,
  getVendors,
  getSubscriptions,
  getAssets,
  getDebts,
  getEmployees,
} from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function csvRow(values: Array<string | number | null | undefined>) {
  return values.map(csvCell).join(",");
}

export async function GET() {
  try {
    const [transactions, invoices, loans, distributions, vendors, subscriptions, assets, debts, employees] =
      await Promise.all([
        getTransactions(),
        getInvoices(),
        getLoanLedger(),
        getProfitDistributions(),
        getVendors(),
        getSubscriptions(),
        getAssets(),
        getDebts(),
        getEmployees(),
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
      ...vendors.map((vendor) =>
        csvRow(["Vendors", vendor.createdAt, "vendor", vendor.name, vendor.status, vendor.notes, ""])
      ),
      ...subscriptions.map((subscription) =>
        csvRow([
          "Subscriptions",
          subscription.renewalDate,
          subscription.billingCycle,
          subscription.vendorName,
          subscription.status,
          subscription.notes,
          subscription.cost,
        ])
      ),
      ...assets.map((asset) =>
        csvRow([
          "Assets",
          asset.purchaseDate,
          "asset",
          asset.name,
          asset.condition,
          asset.notes,
          asset.cost,
        ])
      ),
      ...debts.map((debt) =>
        csvRow([
          "Debts",
          debt.dueDate,
          "debt",
          debt.counterparty,
          debt.status,
          debt.notes,
          debt.remainingBalance,
        ])
      ),
      ...employees.map((employee) =>
        csvRow([
          "Employees",
          employee.startDate,
          "employee",
          employee.fullName,
          employee.status,
          employee.role,
          employee.salary ?? "",
        ])
      ),
    ];

    return new Response(rows.join("\n"), {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="sanestix-finance-export.csv"',
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown export error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
