"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
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
