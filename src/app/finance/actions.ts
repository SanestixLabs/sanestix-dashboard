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
  const payDayRaw = formData.get("payDay");
  const payDay = payDayRaw && String(payDayRaw).trim() !== "" ? Number(payDayRaw) : null;

  if (
    !fullName ||
    (salary !== null && !(salary >= 0)) ||
    (payDay !== null && !(Number.isInteger(payDay) && payDay >= 1 && payDay <= 31))
  ) {
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
    pay_day: payDay,
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

export async function updateEmployeePayDay(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const payDayRaw = String(formData.get("payDay") ?? "").trim();
  const payDay = payDayRaw === "" ? null : Number(payDayRaw);

  if (!employeeId) {
    redirect("/finance/employees?error=Invalid payday update");
  }
  if (payDay !== null && !(Number.isInteger(payDay) && payDay >= 1 && payDay <= 31)) {
    redirect("/finance/employees?error=Payday must be a day of month between 1 and 31");
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("employees")
    .update({ pay_day: payDay })
    .eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect("/finance/employees");
}
