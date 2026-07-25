#!/usr/bin/env bash
# Sanestix Finance — require account password to delete a transaction, and
# require it once per login session to open the Finance module at all.
# Run from the ROOT of your repo (same place as the previous scripts).
set -e

mkdir -p src/components/finance src/app/finance/verify src/app/finance src/app/auth

echo "1/6 — Overwriting actions.ts (password check on delete + new verifyFinanceAccess)..."
cat > src/app/finance/actions.ts << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";

export async function addTransaction(formData: FormData) {
  const kind = String(formData.get("kind") ?? "");
  const category = String(formData.get("category") ?? "") || null;
  const amount = Number(formData.get("amount"));
  const occurredOn = String(formData.get("occurredOn") ?? "");
  const note = String(formData.get("note") ?? "") || null;

  if (!["revenue", "expense"].includes(kind) || !occurredOn || !(amount > 0)) {
    redirect("/finance/transactions?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("finance_transactions").insert({
    kind,
    category,
    amount,
    occurred_on: occurredOn,
    note,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/transactions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/transactions");
  revalidatePath("/finance");
  redirect("/finance/transactions");
}

export async function deleteTransaction(formData: FormData) {
  const transactionId = String(formData.get("transactionId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/finance/transactions");

  if (!transactionId) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Missing transaction id")}`);
  }

  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this transaction")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete a transaction")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Transaction was not deleted.")}`);
  }

  const { error } = await supabase.from("finance_transactions").delete().eq("id", transactionId);

  if (error) {
    redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/transactions");
  revalidatePath("/finance/income");
  revalidatePath("/finance/expenses");
  revalidatePath("/finance");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Finance module session gate — asks for the account password once before
// letting a signed-in user into /finance/*, then sets a session cookie
// (cleared on sign-out) so they aren't asked again until they log in again.
// ---------------------------------------------------------------------------

export async function verifyFinanceAccess(formData: FormData) {
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/finance");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "You must be signed in."
      )}`
    );
  }

  if (!password) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "Password is required."
      )}`
    );
  }

  const { error } = await supabase.auth.signInWithPassword({ email: user.email, password });

  if (error) {
    redirect(
      `/finance/verify?redirectTo=${encodeURIComponent(redirectTo)}&error=${encodeURIComponent(
        "Incorrect password."
      )}`
    );
  }

  const cookieStore = await cookies();
  cookieStore.set("finance_verified", "1", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  });

  redirect(redirectTo);
}

export async function addInvoice(formData: FormData) {
  const clientName = String(formData.get("clientName") ?? "");
  const amount = Number(formData.get("amount"));
  const status = String(formData.get("status") ?? "outstanding");
  const dueDate = String(formData.get("dueDate") ?? "");

  if (!clientName || !dueDate || !(amount > 0)) {
    redirect("/finance/invoices?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("invoices").insert({
    client_name: clientName,
    amount,
    status,
    due_date: dueDate,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect("/finance/invoices");
}

export async function updateInvoiceStatus(formData: FormData) {
  const invoiceId = String(formData.get("invoiceId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!invoiceId || !["outstanding", "paid", "overdue"].includes(status)) {
    redirect("/finance/invoices?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("invoices").update({ status }).eq("id", invoiceId);

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect("/finance/invoices");
}

export async function addLoanEntry(formData: FormData) {
  const founderId = String(formData.get("founderId") ?? "");
  const direction = String(formData.get("direction") ?? "");
  const amount = Number(formData.get("amount"));
  const occurredOn = String(formData.get("occurredOn") ?? "");
  const description = String(formData.get("description") ?? "");

  if (!founderId || !direction || !occurredOn || !description || !(amount > 0)) {
    redirect("/finance/loans?error=Please fill in every field with a valid amount");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("founder_loans").insert({
    founder_id: founderId,
    direction,
    amount,
    occurred_on: occurredOn,
    description,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/loans?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/loans");
  redirect("/finance/loans");
}

export async function addProfitDistribution(formData: FormData) {
  const periodMonth = String(formData.get("periodMonth") ?? "");
  const grossProfit = Number(formData.get("grossProfit"));
  const capitalReserve = Number(formData.get("capitalReserve") ?? 0);
  const loanRepayment = Number(formData.get("loanRepayment") ?? 0);
  const charityPct = Number(formData.get("charityPct") ?? 10);
  const note = String(formData.get("note") ?? "") || null;

  if (!periodMonth || !(grossProfit >= 0)) {
    redirect("/finance/profit-split?error=Please provide a period and a valid gross profit");
  }

  const distributable = Math.max(0, grossProfit - capitalReserve - loanRepayment);
  const charityAmount = distributable * (charityPct / 100);
  const perFounderAmount = (distributable - charityAmount) / 3;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("profit_distributions").insert({
    period_month: `${periodMonth}-01`,
    gross_profit: grossProfit,
    capital_reserve: capitalReserve,
    loan_repayment: loanRepayment,
    distributable_profit: distributable,
    charity_pct: charityPct,
    charity_amount: charityAmount,
    per_founder_amount: perFounderAmount,
    note,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/profit-split?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/profit-split");
  redirect("/finance/profit-split");
}

// ---------------------------------------------------------------------------
// Phase 2 registers — Vendors, Subscriptions, Assets, Debts, Employees
// ---------------------------------------------------------------------------

export async function addVendor(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const category = String(formData.get("category") ?? "") || null;
  const contactPerson = String(formData.get("contactPerson") ?? "") || null;
  const contactEmail = String(formData.get("contactEmail") ?? "") || null;
  const paymentTerms = String(formData.get("paymentTerms") ?? "") || null;
  const status = String(formData.get("status") ?? "active");

  if (!name || !["active", "inactive"].includes(status)) {
    redirect("/finance/vendors?error=Please fill in the vendor name");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("vendors").insert({
    name,
    category,
    contact_person: contactPerson,
    contact_email: contactEmail,
    payment_terms: paymentTerms,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/vendors");
  redirect("/finance/vendors");
}

export async function updateVendorStatus(formData: FormData) {
  const vendorId = String(formData.get("vendorId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!vendorId || !["active", "inactive"].includes(status)) {
    redirect("/finance/vendors?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("vendors").update({ status }).eq("id", vendorId);

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/vendors");
  redirect("/finance/vendors");
}

export async function addSubscription(formData: FormData) {
  const vendorName = String(formData.get("vendorName") ?? "").trim();
  const cost = Number(formData.get("cost"));
  const billingCycle = String(formData.get("billingCycle") ?? "monthly");
  const renewalDate = String(formData.get("renewalDate") ?? "") || null;
  const owner = String(formData.get("owner") ?? "") || null;
  const status = String(formData.get("status") ?? "active");

  if (!vendorName || !(cost >= 0) || !["monthly", "annual"].includes(billingCycle)) {
    redirect("/finance/subscriptions?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("subscriptions").insert({
    vendor_name: vendorName,
    cost,
    billing_cycle: billingCycle,
    renewal_date: renewalDate,
    owner,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/subscriptions");
  redirect("/finance/subscriptions");
}

export async function updateSubscriptionStatus(formData: FormData) {
  const subscriptionId = String(formData.get("subscriptionId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!subscriptionId || !["active", "cancelled"].includes(status)) {
    redirect("/finance/subscriptions?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("subscriptions")
    .update({ status })
    .eq("id", subscriptionId);

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/subscriptions");
  redirect("/finance/subscriptions");
}

export async function addAsset(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const purchaseDate = String(formData.get("purchaseDate") ?? "");
  const cost = Number(formData.get("cost"));
  const owner = String(formData.get("owner") ?? "") || null;
  const condition = String(formData.get("condition") ?? "good");
  const serialNumber = String(formData.get("serialNumber") ?? "") || null;

  if (
    !name ||
    !purchaseDate ||
    !(cost >= 0) ||
    !["new", "good", "fair", "poor", "disposed"].includes(condition)
  ) {
    redirect("/finance/assets?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("assets").insert({
    name,
    purchase_date: purchaseDate,
    cost,
    owner,
    condition,
    serial_number: serialNumber,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/assets");
  redirect("/finance/assets");
}

export async function updateAssetCondition(formData: FormData) {
  const assetId = String(formData.get("assetId") ?? "");
  const condition = String(formData.get("condition") ?? "");

  if (!assetId || !["new", "good", "fair", "poor", "disposed"].includes(condition)) {
    redirect("/finance/assets?error=Invalid condition update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("assets").update({ condition }).eq("id", assetId);

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/assets");
  redirect("/finance/assets");
}

export async function addDebt(formData: FormData) {
  const counterparty = String(formData.get("counterparty") ?? "").trim();
  const principal = Number(formData.get("principal"));
  const paidAmount = Number(formData.get("paidAmount") ?? 0);
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const status = String(formData.get("status") ?? "outstanding");

  if (!counterparty || !(principal >= 0) || !(paidAmount >= 0)) {
    redirect("/finance/debts?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("debts").insert({
    counterparty,
    principal,
    paid_amount: paidAmount,
    due_date: dueDate,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/debts");
  redirect("/finance/debts");
}

export async function updateDebtStatus(formData: FormData) {
  const debtId = String(formData.get("debtId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!debtId || !["outstanding", "paid", "overdue"].includes(status)) {
    redirect("/finance/debts?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("debts").update({ status }).eq("id", debtId);

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/debts");
  redirect("/finance/debts");
}

export async function addEmployee(formData: FormData) {
  const fullName = String(formData.get("fullName") ?? "").trim();
  const role = String(formData.get("role") ?? "") || null;
  const salaryRaw = formData.get("salary");
  const salary = salaryRaw && String(salaryRaw).trim() !== "" ? Number(salaryRaw) : null;
  const startDate = String(formData.get("startDate") ?? "") || null;
  const status = String(formData.get("status") ?? "active");

  if (!fullName || (salary !== null && !(salary >= 0))) {
    redirect("/finance/employees?error=Please fill in every required field");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("employees").insert({
    full_name: fullName,
    role,
    salary,
    start_date: startDate,
    status,
    created_by: user?.id ?? null,
  });

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  redirect("/finance/employees");
}

export async function updateEmployeeStatus(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!employeeId || !["active", "inactive"].includes(status)) {
    redirect("/finance/employees?error=Invalid status update");
  }

  const supabase = await createClient();
  const { error } = await supabase.from("employees").update({ status }).eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  redirect("/finance/employees");
}
SANESTIX_EOF

echo "2/6 — Overwriting delete-transaction-button.tsx (adds inline password prompt)..."
cat > src/components/finance/delete-transaction-button.tsx << 'SANESTIX_EOF'
"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";
import { deleteTransaction } from "@/app/finance/actions";

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
SANESTIX_EOF

echo "3/6 — New file: /finance/verify password gate page..."
cat > src/app/finance/verify/page.tsx << 'SANESTIX_EOF'
import { Lock } from "lucide-react";
import { verifyFinanceAccess } from "@/app/finance/actions";

export const dynamic = "force-dynamic";

export default async function FinanceVerifyPage({
  searchParams,
}: {
  searchParams: Promise<{ redirectTo?: string; error?: string }>;
}) {
  const params = await searchParams;
  const redirectTo = params.redirectTo || "/finance";

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-sm border border-outline-variant bg-surface rounded-[2px] p-6">
        <div className="flex items-center gap-2 text-on-surface">
          <Lock size={18} />
          <h1 className="text-[15px] font-semibold tracking-tight">Confirm it&apos;s you</h1>
        </div>
        <p className="mt-2 text-[13px] text-on-surface-variant">
          Enter your account password to open the Finance module. You won&apos;t be asked again
          until you sign in again.
        </p>

        <form action={verifyFinanceAccess} className="mt-4 space-y-3">
          <input type="hidden" name="redirectTo" value={redirectTo} />

          {params.error && (
            <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
              {params.error}
            </div>
          )}

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Password
            </label>
            <input
              type="password"
              name="password"
              required
              autoFocus
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Unlock Finance
          </button>
        </form>
      </div>
    </div>
  );
}
SANESTIX_EOF

echo "4/6 — Overwriting proxy.ts (adds Finance session gate check)..."
cat > src/proxy.ts << 'SANESTIX_EOF'
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

  // Finance module gate: signed-in users still need to confirm their
  // account password once before entering /finance/*. The "finance_verified"
  // cookie is set by verifyFinanceAccess() after a correct password, and is
  // cleared on sign-out, so this re-prompts on every new login session.
  const isFinanceRoute = path.startsWith("/finance");
  const isFinanceVerifyRoute = path.startsWith("/finance/verify");
  const financeVerified = request.cookies.get("finance_verified")?.value === "1";

  if (user && isFinanceRoute && !isFinanceVerifyRoute && !financeVerified) {
    const url = request.nextUrl.clone();
    url.pathname = "/finance/verify";
    url.searchParams.set("redirectTo", path);
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
SANESTIX_EOF

echo "5/6 — Overwriting auth/actions.ts (clears finance_verified cookie on sign out)..."
cat > src/app/auth/actions.ts << 'SANESTIX_EOF'
"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";

export async function signIn(formData: FormData) {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    redirect(`/login?error=${encodeURIComponent(error.message)}`);
  }

  redirect(redirectTo || "/");
}

export async function signUp(formData: FormData) {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");
  const fullName = String(formData.get("fullName") ?? "");

  const supabase = await createClient();
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { full_name: fullName },
      emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/confirm`,
    },
  });

  if (error) {
    redirect(`/signup?error=${encodeURIComponent(error.message)}`);
  }

  redirect("/login?message=Check your email to confirm your account");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  const cookieStore = await cookies();
  cookieStore.delete("finance_verified");
  redirect("/login");
}
SANESTIX_EOF

echo "6/6 — Overwriting income + expenses pages (show error banner for wrong-password deletes)..."
cat > src/app/finance/income/page.tsx << 'SANESTIX_EOF'
import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { TransactionTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function IncomePage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const income = (await getTransactions()).filter((transaction) => transaction.kind === "revenue");
  const total = income.reduce((sum, transaction) => sum + transaction.amount, 0);
  const sourceCount = new Set(income.map((transaction) => transaction.category ?? "uncategorized")).size;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Income"]}>
      {params.error && (
        <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
          {params.error}
        </div>
      )}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Income</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Cash received from clients, commissions, retainers, and other company inflows.
          </p>
        </div>
        <Link
          href="/finance/transactions"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add income
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total income
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-success">
            {formatCurrency(total)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Entries
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{income.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Sources
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{sourceCount}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Income Register</CardTitle>
        <CardDescription>All recorded inflows, newest first.</CardDescription>
        <div className="mt-4">
          <TransactionTable
            transactions={income}
            emptyLabel="No income entries yet."
            redirectTo="/finance/income"
          />
        </div>
      </Card>
    </DashboardShell>
  );
}
SANESTIX_EOF

cat > src/app/finance/expenses/page.tsx << 'SANESTIX_EOF'
import Link from "next/link";
import { Plus } from "lucide-react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FinanceTabs } from "@/components/layout/finance-tabs";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { TransactionTable } from "@/components/finance/finance-ledger-table";
import { formatCurrency } from "@/lib/utils";
import { getTransactions } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

export default async function ExpensesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const expenses = (await getTransactions()).filter((transaction) => transaction.kind === "expense");
  const total = expenses.reduce((sum, transaction) => sum + transaction.amount, 0);
  const paidBySaad = expenses
    .filter((transaction) => transaction.note?.toLowerCase().includes("paid by saad"))
    .reduce((sum, transaction) => sum + transaction.amount, 0);

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Finance", "Expenses"]}>
      {params.error && (
        <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
          {params.error}
        </div>
      )}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Expenses</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Company expenses separated from reimbursements and founder loan repayments.
          </p>
        </div>
        <Link
          href="/finance/transactions"
          className="inline-flex w-fit items-center gap-2 bg-primary px-4 py-2 text-[11px] font-mono-data uppercase tracking-wider text-on-primary transition hover:brightness-110"
        >
          <Plus size={14} />
          Add expense
        </Link>
      </div>

      <FinanceTabs />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total expenses
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-error">
            {formatCurrency(total)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Paid by Saad
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight text-warning">
            {formatCurrency(paidBySaad)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Entries
          </p>
          <p className="mt-2 text-[24px] font-bold tracking-tight">{expenses.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>Expense Ledger</CardTitle>
        <CardDescription>All company expenses, newest first.</CardDescription>
        <div className="mt-4">
          <TransactionTable
            transactions={expenses}
            emptyLabel="No expense entries yet."
            redirectTo="/finance/expenses"
          />
        </div>
      </Card>
    </DashboardShell>
  );
}
SANESTIX_EOF

echo "Done. Building..."
npm run build
