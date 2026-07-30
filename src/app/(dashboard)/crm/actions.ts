"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { confirmPasswordOrRedirect } from "@/lib/auth-confirm";
import { recordActivity } from "@/lib/audit";
import { LEAD_STAGES } from "@/lib/types";

const VALID_STAGES = LEAD_STAGES.map((s) => s.value);

// ---------------------------------------------------------------------------
// Companies
// ---------------------------------------------------------------------------

export async function addCompany(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const industry = String(formData.get("industry") ?? "") || null;
  const website = String(formData.get("website") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!name) redirect("/crm/companies?error=Please enter a company name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_companies")
    .insert({ name, industry, website, notes, created_by: user?.id ?? null })
    .select("id")
    .single();

  if (error) redirect(`/crm/companies?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_companies",
    entityId: inserted?.id ?? null,
    summary: `Company "${name}" added`,
    notify: false,
  });

  revalidatePath("/crm/companies");
  redirect("/crm/companies");
}

export async function deleteCompany(formData: FormData) {
  const companyId = String(formData.get("companyId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/companies";

  if (!companyId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing company id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_companies")
    .select("name")
    .eq("id", companyId)
    .maybeSingle();
  const { error } = await supabase.from("crm_companies").delete().eq("id", companyId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_companies",
    entityId: companyId,
    summary: `Company "${existing?.name ?? companyId}" deleted`,
    notify: true,
    notifyLink: "/crm/companies",
  });

  revalidatePath("/crm/companies");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Contacts
// ---------------------------------------------------------------------------

export async function addContact(formData: FormData) {
  const fullName = String(formData.get("fullName") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const email = String(formData.get("email") ?? "") || null;
  const phone = String(formData.get("phone") ?? "") || null;
  const title = String(formData.get("title") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!fullName) redirect("/crm/contacts?error=Please enter a contact name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_contacts")
    .insert({
      full_name: fullName,
      company_id: companyId,
      email,
      phone,
      title,
      notes,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm/contacts?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_contacts",
    entityId: inserted?.id ?? null,
    summary: `Contact "${fullName}" added`,
    notify: false,
  });

  revalidatePath("/crm/contacts");
  redirect("/crm/contacts");
}

export async function deleteContact(formData: FormData) {
  const contactId = String(formData.get("contactId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm/contacts";

  if (!contactId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing contact id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_contacts")
    .select("full_name")
    .eq("id", contactId)
    .maybeSingle();
  const { error } = await supabase.from("crm_contacts").delete().eq("id", contactId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_contacts",
    entityId: contactId,
    summary: `Contact "${existing?.full_name ?? contactId}" deleted`,
    notify: true,
    notifyLink: "/crm/contacts",
  });

  revalidatePath("/crm/contacts");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Leads (the pipeline)
// ---------------------------------------------------------------------------

export async function addLead(formData: FormData) {
  const title = String(formData.get("title") ?? "").trim();
  const companyId = String(formData.get("companyId") ?? "") || null;
  const contactId = String(formData.get("contactId") ?? "") || null;
  const value = Number(formData.get("value") ?? 0);
  const source = String(formData.get("source") ?? "") || null;
  const expectedCloseDate = String(formData.get("expectedCloseDate") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!title || value < 0) {
    redirect("/crm?error=Please fill in the lead title with a valid value");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("crm_leads")
    .insert({
      title,
      company_id: companyId,
      contact_id: contactId,
      value,
      source,
      owner_id: user?.id ?? null,
      expected_close_date: expectedCloseDate,
      notes,
      stage: "new",
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) redirect(`/crm?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "crm_leads",
    entityId: inserted?.id ?? null,
    summary: `New lead "${title}"`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect("/crm");
}

/**
 * Move a lead to a new pipeline stage. Moving a lead to "won" auto-creates
 * a draft Project row and links it back via converted_project_id — this is
 * the real CRM → Projects handoff (not just two disconnected modules).
 * Safe to call repeatedly: if the lead was already won, it won't create a
 * second project.
 */
export async function updateLeadStage(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const stage = String(formData.get("stage") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm");

  if (!leadId || !VALID_STAGES.includes(stage as (typeof VALID_STAGES)[number])) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid stage update")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: lead } = await supabase
    .from("crm_leads")
    .select("id, title, value, company_id, converted_project_id, stage")
    .eq("id", leadId)
    .maybeSingle();

  if (!lead) redirect(`${redirectTo}?error=${encodeURIComponent("Lead not found")}`);

  const { error } = await supabase.from("crm_leads").update({ stage }).eq("id", leadId);
  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind: "stage_change",
    content: `Stage changed to "${stage}"`,
    created_by: user?.id ?? null,
  });

  let projectId: string | null = null;

  if (stage === "won" && !lead.converted_project_id) {
    const { data: project, error: projectError } = await supabase
      .from("projects")
      .insert({
        name: lead.title,
        company_id: lead.company_id,
        status: "on_track",
        source_lead_id: leadId,
        notes: `Auto-created from won lead (deal value ${lead.value}).`,
        created_by: user?.id ?? null,
      })
      .select("id")
      .single();

    if (!projectError && project) {
      projectId = project.id;
      await supabase.from("crm_leads").update({ converted_project_id: project.id }).eq("id", leadId);
    }
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "crm_leads",
    entityId: leadId,
    summary: projectId
      ? `Lead "${lead.title}" won — draft project created`
      : `Lead "${lead.title}" moved to ${stage}`,
    notify: stage === "won",
    notifyLink: projectId ? "/projects" : "/crm",
  });

  revalidatePath("/crm");
  revalidatePath(`/crm/leads/${leadId}`);
  revalidatePath("/projects");
  redirect(redirectTo);
}

export async function deleteLead(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/crm";

  if (!leadId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing lead id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("crm_leads")
    .select("title")
    .eq("id", leadId)
    .maybeSingle();
  const { error } = await supabase.from("crm_leads").delete().eq("id", leadId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "crm_leads",
    entityId: leadId,
    summary: `Lead "${existing?.title ?? leadId}" deleted`,
    notify: true,
    notifyLink: "/crm",
  });

  revalidatePath("/crm");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead notes / activity log
// ---------------------------------------------------------------------------

export async function addLeadNote(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const kind = String(formData.get("kind") ?? "note");
  const content = String(formData.get("content") ?? "").trim();
  const redirectTo = `/crm/leads/${leadId}`;

  if (!leadId || !content) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please write a note before saving")}`);
  }
  if (!["note", "call", "email", "meeting"].includes(kind)) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Invalid note type")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_activities").insert({
    lead_id: leadId,
    kind,
    content,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  // Touch updated_at so the lead surfaces near the top of "recently active".
  await supabase.from("crm_leads").update({ updated_at: new Date().toISOString() }).eq("id", leadId);

  revalidatePath(redirectTo);
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Lead follow-up tasks
// ---------------------------------------------------------------------------

export async function addLeadTask(formData: FormData) {
  const leadId = String(formData.get("leadId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const dueDate = String(formData.get("dueDate") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? `/crm/leads/${leadId}`);

  if (!leadId || !title || !dueDate) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Please fill in the task title and due date")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("crm_lead_tasks").insert({
    lead_id: leadId,
    title,
    due_date: dueDate,
    created_by: user?.id ?? null,
  });

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function toggleLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const done = formData.get("done") === "true";
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").update({ done: !done }).eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}

export async function deleteLeadTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const redirectTo = String(formData.get("redirectTo") ?? "/crm/tasks");

  if (!taskId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const { error } = await supabase.from("crm_lead_tasks").delete().eq("id", taskId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  revalidatePath(redirectTo);
  revalidatePath("/crm/tasks");
  redirect(redirectTo);
}
