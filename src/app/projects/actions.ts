"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { recordActivity } from "@/lib/audit";
import type { TaskStatus } from "@/lib/types";

const PROJECT_STATUSES = ["on_track", "at_risk", "delayed", "completed"];
const TASK_STATUSES: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];
const TASK_PRIORITIES = ["low", "medium", "high", "urgent"];

// ---------------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------------

export async function addProject(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const clientName = String(formData.get("clientName") ?? "") || null;
  const description = String(formData.get("description") ?? "") || null;
  const status = String(formData.get("status") ?? "on_track");
  const ownerId = String(formData.get("ownerId") ?? "") || null;
  const startDate = String(formData.get("startDate") ?? "") || null;
  const endDate = String(formData.get("endDate") ?? "") || null;
  const budgetRaw = String(formData.get("budget") ?? "");
  const budget = budgetRaw ? Number(budgetRaw) : null;

  if (!name || !PROJECT_STATUSES.includes(status)) {
    redirect("/projects?error=Please fill in the project name");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("projects")
    .insert({
      name,
      client_name: clientName,
      description,
      status,
      owner_id: ownerId,
      start_date: startDate,
      end_date: endDate,
      budget,
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/projects?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "projects",
    entityId: inserted?.id ?? null,
    summary: `Project "${name}" created`,
    notify: true,
    notifyLink: `/projects/${inserted?.id}`,
  });

  revalidatePath("/projects");
  revalidatePath("/");
  redirect("/projects");
}

export async function updateProjectStatus(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const status = String(formData.get("status") ?? "");

  if (!projectId || !PROJECT_STATUSES.includes(status)) {
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

  if (error) {
    redirect(`/projects?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "projects",
    entityId: projectId,
    summary: `Project "${existing?.name ?? projectId}" marked ${status.replace("_", " ")}`,
    notifyLink: "/projects",
  });

  revalidatePath("/projects");
  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/");
  redirect("/projects");
}

export async function deleteProject(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const password = String(formData.get("password") ?? "");
  const redirectTo = "/projects";

  if (!projectId) redirect(`${redirectTo}?error=${encodeURIComponent("Missing project id")}`);
  if (!password) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Enter your password to delete this project")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    redirect(`${redirectTo}?error=${encodeURIComponent("You must be signed in to delete a project")}`);
  }

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password,
  });

  if (authError) {
    redirect(`${redirectTo}?error=${encodeURIComponent("Incorrect password. Nothing was deleted.")}`);
  }

  const { data: existing } = await supabase
    .from("projects")
    .select("name")
    .eq("id", projectId)
    .maybeSingle();

  // Tasks, task_assignees, task_comments and project_members all cascade
  // via their foreign keys (see supabase/schema-phase5-projects.sql).
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
  revalidatePath("/");
  redirect(redirectTo);
}

// ---------------------------------------------------------------------------
// Project members
// ---------------------------------------------------------------------------

export async function addProjectMember(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const memberId = String(formData.get("memberId") ?? "");

  if (!projectId || !memberId) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Choose someone to add")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("project_members")
    .insert({ project_id: projectId, member_id: memberId });

  // Unique-constraint violation just means they're already a member — not
  // worth surfacing as an error.
  if (error && error.code !== "23505") {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  if (!error) {
    await recordActivity({
      supabase,
      actorId: user?.id ?? null,
      actorEmail: user?.email ?? null,
      action: "update",
      entity: "project_members",
      entityId: projectId,
      summary: "Team member added to project",
      notifyLink: `/projects/${projectId}`,
    });
  }

  revalidatePath(`/projects/${projectId}`);
  redirect(`/projects/${projectId}`);
}

export async function removeProjectMember(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const memberId = String(formData.get("memberId") ?? "");

  if (!projectId || !memberId) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Missing member")}`);
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("project_members")
    .delete()
    .eq("project_id", projectId)
    .eq("member_id", memberId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/projects/${projectId}`);
  redirect(`/projects/${projectId}`);
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

export async function addTask(formData: FormData) {
  const projectId = String(formData.get("projectId") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "") || null;
  const priority = String(formData.get("priority") ?? "medium");
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const assigneeIds = formData.getAll("assigneeIds").map(String).filter(Boolean);

  if (!projectId || !title || !TASK_PRIORITIES.includes(priority)) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Please fill in a task title")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: inserted, error } = await supabase
    .from("tasks")
    .insert({
      project_id: projectId,
      title,
      description,
      priority,
      due_date: dueDate,
      status: "backlog",
      position: Date.now(),
      created_by: user?.id ?? null,
    })
    .select("id")
    .single();

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  if (assigneeIds.length && inserted?.id) {
    await supabase
      .from("task_assignees")
      .insert(assigneeIds.map((memberId) => ({ task_id: inserted.id, member_id: memberId })));
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "insert",
    entity: "tasks",
    entityId: inserted?.id ?? null,
    summary: `Task "${title}" added`,
    notifyLink: `/projects/${projectId}`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
  redirect(`/projects/${projectId}`);
}

/**
 * Called directly from the Kanban board's drag-and-drop handler (not a
 * <form> submit) — moves a task to a new column and persists the resulting
 * column order. No redirect: the client already updated optimistically,
 * this just needs the data to be correct on the next refresh.
 */
export async function moveTask(
  taskId: string,
  projectId: string,
  newStatus: TaskStatus,
  destinationOrderedIds: string[]
) {
  if (!TASK_STATUSES.includes(newStatus)) return;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error: statusError } = await supabase
    .from("tasks")
    .update({ status: newStatus, updated_at: new Date().toISOString() })
    .eq("id", taskId);

  if (statusError) {
    console.error("moveTask: failed to update status:", statusError.message);
    return;
  }

  await Promise.all(
    destinationOrderedIds.map((id, index) =>
      supabase.from("tasks").update({ position: index }).eq("id", id)
    )
  );

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "update",
    entity: "tasks",
    entityId: taskId,
    summary: `Task moved to ${newStatus.replace("_", " ")}`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
  revalidatePath("/");
}

export async function updateTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");
  const priority = String(formData.get("priority") ?? "medium");
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const assigneeIds = formData.getAll("assigneeIds").map(String).filter(Boolean);

  if (!taskId || !TASK_PRIORITIES.includes(priority)) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Invalid task update")}`);
  }

  const supabase = await createClient();

  const { error } = await supabase
    .from("tasks")
    .update({ priority, due_date: dueDate, updated_at: new Date().toISOString() })
    .eq("id", taskId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  // Simplest correct way to sync a many-to-many list from a checkbox form:
  // clear it and reinsert what's checked now.
  await supabase.from("task_assignees").delete().eq("task_id", taskId);
  if (assigneeIds.length) {
    await supabase
      .from("task_assignees")
      .insert(assigneeIds.map((memberId) => ({ task_id: taskId, member_id: memberId })));
  }

  revalidatePath(`/projects/${projectId}`);
}

export async function deleteTask(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");

  if (!taskId) redirect(`/projects/${projectId}?error=${encodeURIComponent("Missing task id")}`);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: existing } = await supabase
    .from("tasks")
    .select("title")
    .eq("id", taskId)
    .maybeSingle();

  const { error } = await supabase.from("tasks").delete().eq("id", taskId);

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  await recordActivity({
    supabase,
    actorId: user?.id ?? null,
    actorEmail: user?.email ?? null,
    action: "delete",
    entity: "tasks",
    entityId: taskId,
    summary: `Task "${existing?.title ?? taskId}" deleted`,
  });

  revalidatePath(`/projects/${projectId}`);
  revalidatePath("/projects");
}

export async function addTaskComment(formData: FormData) {
  const taskId = String(formData.get("taskId") ?? "");
  const projectId = String(formData.get("projectId") ?? "");
  const body = String(formData.get("body") ?? "").trim();

  if (!taskId || !body) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Comment can't be empty")}`);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from("task_comments")
    .insert({ task_id: taskId, author_id: user?.id ?? null, body });

  if (error) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/projects/${projectId}`);
}
