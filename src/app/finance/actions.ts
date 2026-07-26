"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { recordActivity } from "@/lib/audit";
import { formatCurrency } from "@/lib/utils";

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

  const { data: inserted, error } = await supabase
    .from("finance_transactions")
    .insert({
      kind,
      category,
      amount,
      occurred_on: occurredOn,
      note,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/transactions?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "finance_transactions",
    entityId: inserted?.id ?? null,
    summary: `${kind === "revenue" ? "Income" : "Expense"} of ${formatCurrency(amount)}${category ? ` (${category})` : ""} recorded`,
    notify: true,
    notifyLink: "/finance/transactions",
  });

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

  const { data: existing } = await supabase
    .from("finance_transactions")
    .select("kind, amount, category")
    .eq("id", transactionId)
    .maybeSingle();

  const { error } = await supabase.from("finance_transactions").delete().eq("id", transactionId);

  if (error) {
    redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "finance_transactions",
    entityId: transactionId,
    summary: existing
      ? `${existing.kind === "revenue" ? "Income" : "Expense"} of ${formatCurrency(existing.amount)}${existing.category ? ` (${existing.category})` : ""} deleted`
      : "Transaction deleted",
    notify: true,
    notifyLink: "/finance/transactions",
  });

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

  const { data: inserted, error } = await supabase
    .from("invoices")
    .insert({
      client_name: clientName,
      amount,
      status,
      due_date: dueDate,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "invoices",
    entityId: inserted?.id ?? null,
    summary: `Invoice for ${clientName} (${formatCurrency(amount)}) created`,
    notify: true,
    notifyLink: "/finance/invoices",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("invoices")
    .select("client_name, amount")
    .eq("id", invoiceId)
    .maybeSingle();

  const { error } = await supabase.from("invoices").update({ status }).eq("id", invoiceId);

  if (error) {
    redirect(`/finance/invoices?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "invoices",
    entityId: invoiceId,
    summary: existing
      ? `Invoice for ${existing.client_name} (${formatCurrency(existing.amount)}) marked ${status}`
      : `Invoice marked ${status}`,
    notify: status === "paid" || status === "overdue",
    notifyLink: "/finance/invoices",
  });

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

  const { data: inserted, error } = await supabase
    .from("founder_loans")
    .insert({
      founder_id: founderId,
      direction,
      amount,
      occurred_on: occurredOn,
      description,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/loans?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "founder_loans",
    entityId: inserted?.id ?? null,
    summary: `${direction === "loan_in" ? "Founder loan" : "Loan repayment"} of ${formatCurrency(amount)} recorded`,
    notify: true,
    notifyLink: "/finance/loans",
  });

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

  const { data: inserted, error } = await supabase
    .from("profit_distributions")
    .insert({
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
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/profit-split?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "profit_distributions",
    entityId: inserted?.id ?? null,
    summary: `Profit split for ${periodMonth} created (${formatCurrency(distributable)} distributable)`,
    notify: true,
    notifyLink: "/finance/profit-split",
  });

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

  const { data: inserted, error } = await supabase
    .from("vendors")
    .insert({
      name,
      category,
      contact_person: contactPerson,
      contact_email: contactEmail,
      payment_terms: paymentTerms,
      status,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "vendors",
    entityId: inserted?.id ?? null,
    summary: `Vendor "${name}" added`,
    notifyLink: "/finance/vendors",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("vendors")
    .select("name")
    .eq("id", vendorId)
    .maybeSingle();

  const { error } = await supabase.from("vendors").update({ status }).eq("id", vendorId);

  if (error) {
    redirect(`/finance/vendors?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "vendors",
    entityId: vendorId,
    summary: `Vendor "${existing?.name ?? vendorId}" marked ${status}`,
    notifyLink: "/finance/vendors",
  });

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

  const { data: inserted, error } = await supabase
    .from("subscriptions")
    .insert({
      vendor_name: vendorName,
      cost,
      billing_cycle: billingCycle,
      renewal_date: renewalDate,
      owner,
      status,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "subscriptions",
    entityId: inserted?.id ?? null,
    summary: `Subscription "${vendorName}" (${formatCurrency(cost)}/${billingCycle}) added`,
    notifyLink: "/finance/subscriptions",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("subscriptions")
    .select("vendor_name")
    .eq("id", subscriptionId)
    .maybeSingle();

  const { error } = await supabase
    .from("subscriptions")
    .update({ status })
    .eq("id", subscriptionId);

  if (error) {
    redirect(`/finance/subscriptions?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "subscriptions",
    entityId: subscriptionId,
    summary: `Subscription "${existing?.vendor_name ?? subscriptionId}" marked ${status}`,
    notifyLink: "/finance/subscriptions",
  });

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

  const { data: inserted, error } = await supabase
    .from("assets")
    .insert({
      name,
      purchase_date: purchaseDate,
      cost,
      owner,
      condition,
      serial_number: serialNumber,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "assets",
    entityId: inserted?.id ?? null,
    summary: `Asset "${name}" (${formatCurrency(cost)}) added`,
    notifyLink: "/finance/assets",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("assets")
    .select("name")
    .eq("id", assetId)
    .maybeSingle();

  const { error } = await supabase.from("assets").update({ condition }).eq("id", assetId);

  if (error) {
    redirect(`/finance/assets?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "assets",
    entityId: assetId,
    summary: `Asset "${existing?.name ?? assetId}" condition set to ${condition}`,
    notifyLink: "/finance/assets",
  });

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

  const { data: inserted, error } = await supabase
    .from("debts")
    .insert({
      counterparty,
      principal,
      paid_amount: paidAmount,
      due_date: dueDate,
      status,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "debts",
    entityId: inserted?.id ?? null,
    summary: `Debt with ${counterparty} (${formatCurrency(principal)}) added`,
    notify: true,
    notifyLink: "/finance/debts",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("debts")
    .select("counterparty")
    .eq("id", debtId)
    .maybeSingle();

  const { error } = await supabase.from("debts").update({ status }).eq("id", debtId);

  if (error) {
    redirect(`/finance/debts?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "debts",
    entityId: debtId,
    summary: `Debt with ${existing?.counterparty ?? debtId} marked ${status}`,
    notify: status === "paid",
    notifyLink: "/finance/debts",
  });

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

  const { data: inserted, error } = await supabase
    .from("employees")
    .insert({
      full_name: fullName,
      role,
      salary,
      start_date: startDate,
      status,
      pay_day: payDay,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "employees",
    entityId: inserted?.id ?? null,
    summary: `Employee "${fullName}" added`,
    notifyLink: "/finance/employees",
  });

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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("employees")
    .select("full_name")
    .eq("id", employeeId)
    .maybeSingle();

  const { error } = await supabase.from("employees").update({ status }).eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "employees",
    entityId: employeeId,
    summary: `Employee "${existing?.full_name ?? employeeId}" marked ${status}`,
    notifyLink: "/finance/employees",
  });

  revalidatePath("/finance/employees");
  redirect("/finance/employees");
}

// ---------------------------------------------------------------------------
// Delete support — same "re-enter your password" confirmation pattern as
// deleteTransaction, applied to every Phase 2 register.
// ---------------------------------------------------------------------------

async function confirmPasswordOrRedirect(
  password: string,
  redirectTo: string
): Promise<{ supabase: Awaited<ReturnType<typeof createClient>>; user: { id: string; email: string } }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete this")}`);
  }
  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Nothing was deleted.")}`);
  }

  return { supabase, user: { id: user.id, email: user.email } };
}

export async function deleteVendor(formData: FormData) {
  const vendorId = String(formData.get("vendorId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/vendors";

  if (!vendorId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing vendor id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase.from("vendors").select("name").eq("id", vendorId).maybeSingle();
  const { error } = await supabase.from("vendors").delete().eq("id", vendorId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "vendors",
    entityId: vendorId,
    summary: `Vendor "${existing?.name ?? vendorId}" deleted`,
    notify: true,
    notifyLink: "/finance/vendors",
  });

  revalidatePath("/finance/vendors");
  redirect(redirectTo);
}

export async function deleteSubscription(formData: FormData) {
  const subscriptionId = String(formData.get("subscriptionId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/subscriptions";

  if (!subscriptionId)
    redirect(`${redirectTo}?error=${encodeURIComponent("Missing subscription id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("subscriptions")
    .select("vendor_name")
    .eq("id", subscriptionId)
    .maybeSingle();
  const { error } = await supabase.from("subscriptions").delete().eq("id", subscriptionId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "subscriptions",
    entityId: subscriptionId,
    summary: `Subscription "${existing?.vendor_name ?? subscriptionId}" deleted`,
    notify: true,
    notifyLink: "/finance/subscriptions",
  });

  revalidatePath("/finance/subscriptions");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteAsset(formData: FormData) {
  const assetId = String(formData.get("assetId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/assets";

  if (!assetId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing asset id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase.from("assets").select("name").eq("id", assetId).maybeSingle();
  const { error } = await supabase.from("assets").delete().eq("id", assetId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "assets",
    entityId: assetId,
    summary: `Asset "${existing?.name ?? assetId}" deleted`,
    notify: true,
    notifyLink: "/finance/assets",
  });

  revalidatePath("/finance/assets");
  redirect(redirectTo);
}

export async function deleteDebt(formData: FormData) {
  const debtId = String(formData.get("debtId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/debts";

  if (!debtId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing debt id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("debts")
    .select("counterparty")
    .eq("id", debtId)
    .maybeSingle();
  const { error } = await supabase.from("debts").delete().eq("id", debtId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "debts",
    entityId: debtId,
    summary: `Debt with ${existing?.counterparty ?? debtId} deleted`,
    notify: true,
    notifyLink: "/finance/debts",
  });

  revalidatePath("/finance/debts");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteInvoice(formData: FormData) {
  const invoiceId = String(formData.get("invoiceId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/invoices";

  if (!invoiceId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing invoice id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("invoices")
    .select("client_name, amount")
    .eq("id", invoiceId)
    .maybeSingle();
  const { error } = await supabase.from("invoices").delete().eq("id", invoiceId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "invoices",
    entityId: invoiceId,
    summary: existing
      ? `Invoice for ${existing.client_name} (${formatCurrency(existing.amount)}) deleted`
      : "Invoice deleted",
    notify: true,
    notifyLink: "/finance/invoices",
  });

  revalidatePath("/finance/invoices");
  revalidatePath("/finance");
  redirect(redirectTo);
}

export async function deleteEmployee(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/employees";

  if (!employeeId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing employee id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("employees")
    .select("full_name")
    .eq("id", employeeId)
    .maybeSingle();
  const { error } = await supabase.from("employees").delete().eq("id", employeeId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "employees",
    entityId: employeeId,
    summary: `Employee "${existing?.full_name ?? employeeId}" deleted`,
    notify: true,
    notifyLink: "/finance/employees",
  });

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Payroll — mark a salary as paid for a given month, with an optional photo
// of the payment proof (bank transfer screenshot, receipt, etc).
// ---------------------------------------------------------------------------

export async function markSalaryPaid(formData: FormData) {
  const employeeId = String(formData.get("employeeId") ?? "");
  const amount = Number(formData.get("amount"));
  const payPeriodRaw = String(formData.get("payPeriod") ?? ""); // "YYYY-MM"
  const notes = String(formData.get("notes") ?? "") || null;
  const proof = formData.get("proof");

  if (!employeeId || !(amount > 0) || !/^\d{4}-\d{2}$/.test(payPeriodRaw)) {
    redirect("/finance/employees?error=Please fill in employee, amount and pay period");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  let proofUrl: string | null = null;

  if (proof instanceof File && proof.size > 0) {
    if (!proof.type.startsWith("image/")) {
      redirect("/finance/employees?error=Payment proof must be an image file");
    }
    if (proof.size > 5 * 1024 * 1024) {
      redirect("/finance/employees?error=Payment proof image must be under 5MB");
    }

    const ext = proof.name.split(".").pop()?.toLowerCase() || "jpg";
    const path = `${employeeId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("payment-proofs")
      .upload(path, proof, { contentType: proof.type, upsert: false });

    if (uploadError) {
      redirect(
        `/finance/employees?error=${encodeURIComponent(`Proof upload failed: ${uploadError.message}`)}`
      );
    }

    proofUrl = supabase.storage.from("payment-proofs").getPublicUrl(path).data.publicUrl;
  }

  const { data: employeeRow } = await supabase
    .from("employees")
    .select("full_name")
    .eq("id", employeeId)
    .maybeSingle();

  const { data: inserted, error } = await supabase
    .from("employee_payments")
    .insert({
      employee_id: employeeId,
      amount,
      pay_period: `${payPeriodRaw}-01`,
      proof_url: proofUrl,
      notes,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "employee_payments",
    entityId: inserted?.id ?? null,
    summary: `Salary of ${formatCurrency(amount)} paid to ${employeeRow?.full_name ?? "employee"} for ${payPeriodRaw}`,
    notify: true,
    notifyLink: "/finance/employees",
  });

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect("/finance/employees");
}

export async function deleteEmployeePayment(formData: FormData) {
  const paymentId = String(formData.get("paymentId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/finance/employees";

  if (!paymentId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing payment id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("employee_payments")
    .select("amount, pay_period, employee_id")
    .eq("id", paymentId)
    .maybeSingle();

  let employeeName: string | null = null;
  if (existing?.employee_id) {
    const { data: employeeRow } = await supabase
      .from("employees")
      .select("full_name")
      .eq("id", existing.employee_id)
      .maybeSingle();
    employeeName = employeeRow?.full_name ?? null;
  }

  const { error } = await supabase.from("employee_payments").delete().eq("id", paymentId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "employee_payments",
    entityId: paymentId,
    summary: existing
      ? `Salary payment of ${formatCurrency(existing.amount)} to ${employeeName ?? "employee"} deleted`
      : "Salary payment deleted",
    notify: true,
    notifyLink: "/finance/employees",
  });

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect(redirectTo);
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
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("employees")
    .select("full_name")
    .eq("id", employeeId)
    .maybeSingle();

  const { error } = await supabase
    .from("employees")
    .update({ pay_day: payDay })
    .eq("id", employeeId);

  if (error) {
    redirect(`/finance/employees?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "employees",
    entityId: employeeId,
    summary: `Payday for "${existing?.full_name ?? employeeId}" set to day ${payDay ?? "(cleared)"}`,
    notifyLink: "/finance/employees",
  });

  revalidatePath("/finance/employees");
  revalidatePath("/finance");
  redirect("/finance/employees");
}
