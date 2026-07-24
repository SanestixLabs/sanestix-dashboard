# Finance Module — Reference

The Finance tab is the most complete module in Sanestix OS: 15 pages, all
backed by real Supabase Postgres tables (no mock data). This doc explains
what each page does, which table/action it depends on, and the most common
reason a page fails to load.

## Required setup (do this first)

Two SQL files must be run, **in this order**, in the Supabase SQL editor:

1. `supabase/schema.sql` — creates `profiles`, `finance_transactions`,
   `invoices`, `founder_loans`, `profit_distributions`.
2. `supabase/schema-phase2-registers.sql` — creates `vendors`,
   `subscriptions`, `assets`, `debts`, `employees`.

**If step 2 is skipped, the Vendors / Employees / Subscriptions / Assets /
Debts pages will fail to load.** This is the single most common cause of
"the page won't open" — the query throws `relation "public.X" does not
exist`, and (as of this update) that now surfaces as a readable error card
instead of a blank/crashed page. See `src/app/finance/error.tsx`.

Both files are idempotent (`create table if not exists`), so re-running
them is always safe.

## Error handling

- `src/app/error.tsx` — app-wide fallback for any unhandled error.
- `src/app/finance/error.tsx` — Finance-specific error boundary. Reads the
  thrown error message and shows a targeted hint:
  - `relation ... does not exist` → run the missing schema file.
  - permission denied / RLS → check the table's Row Level Security policy.
  - fetch failed / network → check `.env` Supabase URL/key.
- `src/app/finance/loading.tsx` — skeleton shown while a page's server
  component is fetching (all Finance pages are `force-dynamic`, so this
  fires on every navigation).

## Pages

| Tab | Route | Reads | Writes (Server Action) |
|---|---|---|---|
| Overview | `/finance` | `getFinanceData()` (aggregates transactions + invoices) | — |
| Income | `/finance/income` | `getTransactions()` filtered `kind = "revenue"` | `addTransaction` (finance/transactions) |
| Expenses | `/finance/expenses` | `getTransactions()` filtered `kind = "expense"` | `addTransaction` |
| Transactions | `/finance/transactions` | `getTransactions()` | `addTransaction` |
| Invoices | `/finance/invoices` | `getInvoices()` | `addInvoice`, `updateInvoiceStatus` |
| Investments | `/finance/investments` | `getLoanLedger()` filtered `direction = "loan_in"`, `getLoanBalances()` | `addLoanEntry` (finance/loans) |
| Reimbursements | `/finance/reimbursements` | `getLoanLedger()` filtered `direction = "repayment_out"`, `getLoanBalances()` | `addLoanEntry` |
| Founder Entry | `/finance/loans` | `getLoanLedger()`, `getLoanBalances()`, `getFounders()` | `addLoanEntry` |
| Profit Split | `/finance/profit-split` | `getProfitDistributions()` | `addProfitDistribution` |
| Reports | `/finance/reports` | All of the above **plus** `getVendors`, `getSubscriptions`, `getAssets`, `getDebts`, `getEmployees` | — (read-only; links to CSV export) |
| Vendors | `/finance/vendors` | `getVendors()` | `addVendor`, `updateVendorStatus` |
| Employees | `/finance/employees` | `getEmployees()` | `addEmployee`, `updateEmployeeStatus` |
| Subscriptions | `/finance/subscriptions` | `getSubscriptions()` | `addSubscription`, `updateSubscriptionStatus` |
| Assets | `/finance/assets` | `getAssets()` | `addAsset`, `updateAssetCondition` |
| Debts | `/finance/debts` | `getDebts()` | `addDebt`, `updateDebtStatus` |

All query functions live in `src/lib/supabase/queries.ts`; all mutating
actions live in `src/app/finance/actions.ts` (all `"use server"`).

### Reports page — company-wide summary

`/finance/reports` is the one page that ties every register together. It
now surfaces (in addition to the original cash/invoice/founder figures):

- **Monthly burn** — active subscriptions (annual costs amortized ÷ 12) +
  active employee salaries.
- **Asset book value** — sum of non-disposed asset purchase costs.
- **Outstanding debts** — sum of `remainingBalance` for debts not marked
  `paid`.
- **Active vendors** — count of vendors with `status = "active"`.
- **Net position** — `income − expenses + assetBookValue −
  founderPayable − outstandingDebts`. A rough net-worth figure; it does
  not account for accrued-but-unpaid subscriptions/payroll.
- **Company Registers** panel — live counts across all five Phase 2
  registers.

### CSV export

`GET /api/export/finance` streams a single CSV combining Transactions,
Invoices, Founder Loans, Profit Distributions, Vendors, Subscriptions,
Assets, Debts, and Employees (one `Section` column identifies the source).
Wrapped in try/catch — a failed query now returns a JSON `{ error }` body
with HTTP 500 instead of an unhandled server exception.

## Data model quick reference

- **Transactions** (`finance_transactions`): `kind` (`revenue` | `expense`),
  `category`, `amount`, `occurred_on`, `note`.
- **Invoices**: `client_name`, `amount`, `status` (`outstanding` | `paid` |
  `overdue`), `due_date`.
- **Founder loans** (`founder_loans`): `founder_id`, `direction`
  (`loan_in` | `repayment_out`), `amount`, `occurred_on`, `description`.
  Investments and Reimbursements are both views over this one table,
  filtered by `direction`.
- **Profit distributions**: `period_month`, `gross_profit`,
  `capital_reserve`, `loan_repayment`, `charity_pct` → derives
  `distributable_profit`, `charity_amount`, `per_founder_amount` (split
  evenly three ways).
- **Vendors**: `name`, `category`, `contact_person`, `contact_email`,
  `payment_terms`, `status` (`active` | `inactive`).
- **Subscriptions**: `vendor_name`, `cost`, `billing_cycle` (`monthly` |
  `annual`), `renewal_date`, `owner`, `status` (`active` | `cancelled`).
- **Assets**: `name`, `purchase_date`, `cost`, `owner`, `condition` (`new` |
  `good` | `fair` | `poor` | `disposed`), `serial_number`.
- **Debts**: `counterparty`, `principal`, `paid_amount` → derives
  `remaining_balance`, `due_date`, `status` (`outstanding` | `paid` |
  `overdue`).
- **Employees**: `full_name`, `role`, `salary`, `start_date`, `status`
  (`active` | `inactive`).

## Troubleshooting checklist

If a Finance page won't open:

1. Read the error card — it now tells you the actual Supabase error
   message plus a targeted hint.
2. `relation "public.X" does not exist` → you haven't run
   `schema-phase2-registers.sql` (or `schema.sql`) yet. Run it.
3. Empty page / no rows but no error → RLS is fine, table is just empty.
   Check "empty" is genuinely correct (query the table directly in the
   Supabase SQL editor).
4. `permission denied for relation X` → RLS policy doesn't grant the
   `authenticated` role access. Compare against the working tables in
   `schema.sql` for the expected policy pattern.
5. Everything 500s / nothing loads at all → check
   `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env`
   (or the VPS's `docker-compose` build args — these are baked in at
   `docker compose build` time, so a `.env` edit needs a rebuild, not just
   a restart).
