"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { confirmPasswordOrRedirect } from "@/lib/auth-confirm";
import { recordActivity } from "@/lib/audit";

const VALID_STATUSES = ["on_track", "at_risk", "delayed", "completed"];

export async function addProject(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const clientName = String(formData.get("clientName") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;

  if (!name) redirect("/projects?error=Please enter a project name");

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("projects")
    .insert({ name, client_name: clientName, notes, status: "on_track", created_by: user?.id ?? null })
    .select("id")
    .single();

  if (error) redirect(`/projects?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "create",
    entity: "projects",
    entityId: inserted?.id ?? null,
    summary: `Project "${name}" added`,
    notify: false,
  });

  revalidatePath("/projects");
  redirect("/projects");
}

export async function updateProjectStatus(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!projectId || !VALID_STATUSES.includes(status)) {
    redirect("/projects?error=Invalid status update");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();

  const { error } = await supabase.from("projects").update({ status }).eq("id", projectId);
  if (error) redirect(`/projects?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" status → ${status}`,
    notify: false,
  });

  revalidatePath("/projects");
  redirect("/projects");
}

export async function deleteProject(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/projects";

  if (!projectId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing project id")}`);

  const { supabase, user } = await confirmPasswordOrRedirect(password, redirectTo);
  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();
  const { error } = await supabase.from("projects").delete().eq("id", projectId);

  if (error) redirect(`${redirectTo}?error=${encodeURIComponent(error.message)}`);

  await recordActivity({
    supabase,
    actorId: user.id,
    actorEmail: user.email,
    action: "delete",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" deleted`,
    notify: true,
    notifyLink: "/projects",
  });

  revalidatePath("/projects");
  redirect(redirectTo);
}
