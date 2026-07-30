#!/usr/bin/env bash
# Sanestix — Jira/ClickUp-style Projects upgrades:
#   - Edit a task's title & description (previously priority/due-date only)
#   - Labels/tags on tasks, with a filter toolbar on the Kanban board
#     (filter by assignee, priority, and label)
#   - "My Tasks" — a cross-project panel on the Projects list page showing
#     every open task assigned to you, soonest due first (the Jira/ClickUp
#     "My Work" view)
#
# Run from the ROOT of your repo on the VPS. Safe to re-run.
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "ERROR: run this from the repo root (where package.json and src/app live)."
  exit 1
fi

echo "==> Step 1/3: patching src/lib/types.ts and src/lib/supabase/queries.ts"
python3 - << 'PYEOF'
import pathlib, sys

patches = [
    ("src/lib/types.ts", [
        (
'''export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type TaskPriority = "low" | "medium" | "high" | "urgent";

export interface ProjectPerson {
  id: string;
  fullName: string | null;
}

export interface TaskComment {
  id: string;
  taskId: string;
  authorName: string | null;
  body: string;
  createdAt: string;
}

export interface ProjectTask {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  position: number;
  assignees: ProjectPerson[];
  comments: TaskComment[];
  createdByName: string | null;
  createdAt: string;
}''',
'''export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type TaskPriority = "low" | "medium" | "high" | "urgent";

// A small fixed tag palette (Jira "labels" / ClickUp "tags") rather than
// free-form text, so the board filter dropdown stays a clean, known list
// instead of every task inventing its own one-off tag.
export const TASK_LABELS = [
  "Bug",
  "Feature",
  "Design",
  "Client Request",
  "Tech Debt",
  "Blocked",
] as const;

export interface ProjectPerson {
  id: string;
  fullName: string | null;
}

export interface TaskComment {
  id: string;
  taskId: string;
  authorName: string | null;
  body: string;
  createdAt: string;
}

export interface ProjectTask {
  id: string;
  projectId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  labels: string[];
  position: number;
  assignees: ProjectPerson[];
  comments: TaskComment[];
  createdByName: string | null;
  createdAt: string;
}

// A task assigned to the current user, with enough project context to jump
// straight to it — the data behind the cross-project "My Tasks" panel on
// the Projects list page (the ClickUp/Jira "My Work" equivalent).
export interface MyTask {
  id: string;
  projectId: string;
  projectName: string;
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: string | null;
  overdue: boolean;
  labels: string[];
}'''
        ),
    ]),
    ("src/lib/supabase/queries.ts", [
        (
'''  LoanBalance,
  LoanEntry,
  Project,''',
'''  LoanBalance,
  LoanEntry,
  MyTask,
  Project,'''
        ),
        (
'''    .select(
      "id, project_id, title, description, status, priority, due_date, position, created_at, profiles!tasks_created_by_fkey(full_name), task_assignees(member_id, profiles!task_assignees_member_id_fkey(id, full_name))"
    )''',
'''    .select(
      "id, project_id, title, description, status, priority, due_date, labels, position, created_at, profiles!tasks_created_by_fkey(full_name), task_assignees(member_id, profiles!task_assignees_member_id_fkey(id, full_name))"
    )'''
        ),
        (
'''    return {
      id: row.id,
      projectId: row.project_id,
      title: row.title,
      description: row.description,
      status: row.status,
      priority: row.priority,
      dueDate: row.due_date,
      position: Number(row.position),
      assignees,
      comments,
      createdByName: creator?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}''',
'''    return {
      id: row.id,
      projectId: row.project_id,
      title: row.title,
      description: row.description,
      status: row.status,
      priority: row.priority,
      dueDate: row.due_date,
      labels: row.labels ?? [],
      position: Number(row.position),
      assignees,
      comments,
      createdByName: creator?.full_name ?? null,
      createdAt: row.created_at,
    };
  });
}

/**
 * Every open (not-done) task assigned to the signed-in user, across every
 * project, soonest due first — the cross-project "My Tasks" view (the
 * Jira/ClickUp "My Work" equivalent). Returns [] when signed out rather
 * than throwing, since this is a nice-to-have dashboard widget, not a
 * page whose absence should break anything.
 */
export async function getMyOpenTasks(): Promise<MyTask[]> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];

  const { data: assignedRows, error: assignedError } = await supabase
    .from("task_assignees")
    .select("task_id")
    .eq("member_id", user.id);

  if (assignedError) throw new Error(`Failed to load my tasks: ${assignedError.message}`);

  const taskIds = (assignedRows ?? []).map((r) => r.task_id);
  if (!taskIds.length) return [];

  const { data, error } = await supabase
    .from("tasks")
    .select("id, project_id, title, status, priority, due_date, labels, projects(name)")
    .in("id", taskIds)
    .neq("status", "done")
    .order("due_date", { ascending: true, nullsFirst: false });

  if (error) throw new Error(`Failed to load my tasks: ${error.message}`);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (data ?? []).map((row) => {
    const project = Array.isArray(row.projects) ? row.projects[0] : row.projects;
    return {
      id: row.id,
      projectId: row.project_id,
      projectName: project?.name ?? "Unknown project",
      title: row.title,
      status: row.status,
      priority: row.priority,
      dueDate: row.due_date,
      labels: row.labels ?? [],
      overdue: !!row.due_date && new Date(row.due_date) < today,
    };
  });
}'''
        ),
    ]),
]

failed = False
for filename, replacements in patches:
    p = pathlib.Path(filename)
    if not p.exists():
        print("MISSING FILE:", filename)
        failed = True
        continue
    s = p.read_text()
    for old, new in replacements:
        if new in s:
            print(f"SKIP (already patched): {filename}")
            continue
        if old not in s:
            print(f"PATTERN NOT FOUND in {filename}:")
            print(old[:120])
            failed = True
            continue
        s = s.replace(old, new, 1)
    p.write_text(s)
    print("OK", filename)

if failed:
    sys.exit(1)
PYEOF

echo "==> Step 2/3: writing updated Projects actions, pages, and components"

cat > "src/app/(dashboard)/projects/actions.ts" << 'PROJACTIONS_EOF'
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
  const labels = formData.getAll("labels").map(String).filter(Boolean);

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
      labels,
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
  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "") || null;
  const priority = String(formData.get("priority") ?? "medium");
  const dueDate = String(formData.get("dueDate") ?? "") || null;
  const assigneeIds = formData.getAll("assigneeIds").map(String).filter(Boolean);
  const labels = formData.getAll("labels").map(String).filter(Boolean);

  if (!taskId || !TASK_PRIORITIES.includes(priority)) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Invalid task update")}`);
  }
  if (!title) {
    redirect(`/projects/${projectId}?error=${encodeURIComponent("Task title can't be empty")}`);
  }

  const supabase = await createClient();

  const { error } = await supabase
    .from("tasks")
    .update({
      title,
      description,
      priority,
      due_date: dueDate,
      labels,
      updated_at: new Date().toISOString(),
    })
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
PROJACTIONS_EOF

cat > "src/app/(dashboard)/projects/page.tsx" << 'PROJPAGE_EOF'
import Link from "next/link";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getProjects, getFounders, getMyOpenTasks } from "@/lib/supabase/queries";
import { addProject, updateProjectStatus, deleteProject } from "@/app/(dashboard)/projects/actions";
import { formatCurrency, formatRelativeDate } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STATUS_OPTIONS = [
  { value: "on_track", label: "On Track" },
  { value: "at_risk", label: "At Risk" },
  { value: "delayed", label: "Delayed" },
  { value: "completed", label: "Completed" },
];

const STATUS_TONE: Record<string, "success" | "warning" | "error" | "neutral"> = {
  on_track: "success",
  at_risk: "warning",
  delayed: "error",
  completed: "neutral",
};

export default async function ProjectsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [projects, people, myTasks] = await Promise.all([
    getProjects(),
    getFounders(),
    getMyOpenTasks(),
  ]);

  const activeCount = projects.filter((p) => p.status !== "completed").length;
  const overdueCount = projects.reduce((sum, p) => sum + p.overdueTaskCount, 0);
  const atRiskCount = projects.filter((p) => p.status === "at_risk" || p.status === "delayed")
    .length;

  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Projects</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client delivery workspace — projects, tasks, and ownership, live from Supabase.
        </p>
      </div>

      {myTasks.length > 0 && (
        <Card className="p-6">
          <CardTitle>My Tasks</CardTitle>
          <CardDescription>
            {myTasks.length} open task{myTasks.length === 1 ? "" : "s"} assigned to you, across
            every project — soonest due first.
          </CardDescription>
          <div className="mt-4 space-y-2">
            {myTasks.slice(0, 8).map((t) => {
              const overdueLabel =
                t.dueDate && t.overdue ? formatRelativeDate(t.dueDate).label : null;
              return (
                <Link
                  key={t.id}
                  href={`/projects/${t.projectId}`}
                  className="flex items-center justify-between gap-3 border border-outline-variant bg-background px-3 py-2 text-[12px] transition hover:border-primary/40"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-on-surface">{t.title}</p>
                    <p className="truncate text-[11px] text-on-surface-variant">
                      {t.projectName}
                      {t.labels.length > 0 && ` · ${t.labels.join(", ")}`}
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <StatusPill
                      tone={
                        t.priority === "urgent"
                          ? "error"
                          : t.priority === "high"
                            ? "warning"
                            : "neutral"
                      }
                    >
                      {t.priority}
                    </StatusPill>
                    {t.dueDate && (
                      <span
                        className={`font-mono-data text-[10px] uppercase tracking-wider ${
                          overdueLabel ? "text-error" : "text-on-surface-variant"
                        }`}
                      >
                        {formatRelativeDate(t.dueDate).label}
                      </span>
                    )}
                  </div>
                </Link>
              );
            })}
            {myTasks.length > 8 && (
              <p className="pt-1 text-center text-[11px] text-on-surface-variant">
                +{myTasks.length - 8} more
              </p>
            )}
          </div>
        </Card>
      )}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Total projects
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{projects.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Active
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-primary">{activeCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            At risk / delayed
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-warning">{atRiskCount}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue tasks
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueCount}</p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>New project</CardTitle>
          <CardDescription>Kick off a new piece of client work.</CardDescription>

          <form action={addProject} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Name
              </label>
              <input
                type="text"
                name="name"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Atlas Migration"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Client
              </label>
              <input
                type="text"
                name="clientName"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Owner
              </label>
              <select
                name="ownerId"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">Unassigned</option>
                {people.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.fullName ?? "Unnamed"}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                  Start date
                </label>
                <input
                  type="date"
                  name="startDate"
                  className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                  End date
                </label>
                <input
                  type="date"
                  name="endDate"
                  className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Budget (PKR)
              </label>
              <input
                type="number"
                name="budget"
                min="0"
                step="0.01"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Description
              </label>
              <textarea
                name="description"
                rows={2}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Status
              </label>
              <select
                name="status"
                defaultValue="on_track"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                {STATUS_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Create project
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Project Registry</CardTitle>
          <CardDescription>All projects, newest first.</CardDescription>

          <div className="mt-4 max-h-[640px] overflow-auto">
            <table className="w-full min-w-[760px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Client</th>
                  <th className="pb-2 pr-4">Owner</th>
                  <th className="pb-2 pr-4">Tasks</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 && (
                  <tr>
                    <td colSpan={6} className="py-6 text-center text-on-surface-variant">
                      No projects yet — create the first one on the left.
                    </td>
                  </tr>
                )}
                {projects.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50 align-top">
                    <td className="py-2.5 pr-4">
                      <Link href={`/projects/${p.id}`} className="text-on-surface hover:text-primary">
                        {p.name}
                      </Link>
                      {p.budget !== null && (
                        <p className="mt-0.5 font-mono-data text-[11px] text-on-surface-variant">
                          {formatCurrency(p.budget)}
                        </p>
                      )}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{p.clientName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">{p.ownerName ?? "—"}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.doneTaskCount}/{p.taskCount} done
                      {p.overdueTaskCount > 0 && (
                        <span className="ml-2">
                          <StatusPill tone="error">{p.overdueTaskCount} overdue</StatusPill>
                        </span>
                      )}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="projectId"
                        idValue={p.id}
                        status={STATUS_OPTIONS.find((o) => o.value === p.status)?.label ?? p.status}
                        tone={STATUS_TONE[p.status]}
                        options={STATUS_OPTIONS}
                        action={updateProjectStatus}
                      />
                    </td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end">
                        <RegisterDeleteButton
                          action={deleteProject}
                          idFieldName="projectId"
                          idValue={p.id}
                          redirectTo="/projects"
                          label="project"
                        />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </>
  );
}
PROJPAGE_EOF

cat > src/components/projects/add-task-form.tsx << 'ADDTASKFORM_EOF'
"use client";

import { X } from "lucide-react";
import { addTask } from "@/app/(dashboard)/projects/actions";
import { TASK_LABELS, type ProjectPerson } from "@/lib/types";

export function AddTaskForm({
  projectId,
  members,
  onClose,
}: {
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-md overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <h2 className="text-[16px] font-semibold text-on-surface">New task</h2>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        <form action={addTask} className="mt-4 space-y-3">
          <input type="hidden" name="projectId" value={projectId} />

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Title
            </label>
            <input
              type="text"
              name="title"
              required
              autoFocus
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="e.g. Wire up payment webhook"
            />
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Description
            </label>
            <textarea
              name="description"
              rows={3}
              className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              placeholder="Optional"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue="medium"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Labels
            </label>
            <div className="flex flex-wrap gap-2">
              {TASK_LABELS.map((label) => (
                <label
                  key={label}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input type="checkbox" name="labels" value={label} />
                  {label}
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input type="checkbox" name="assigneeIds" value={m.id} />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">
                  Add project members first to assign tasks.
                </p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Add task
          </button>
        </form>
      </div>
    </div>
  );
}
ADDTASKFORM_EOF

cat > src/components/projects/task-detail-modal.tsx << 'TASKMODAL_EOF'
"use client";

import { useState } from "react";
import { Trash2, X } from "lucide-react";
import { updateTask, deleteTask, addTaskComment } from "@/app/(dashboard)/projects/actions";
import { formatRelativeDate } from "@/lib/utils";
import { TASK_LABELS, type ProjectPerson, type ProjectTask } from "@/lib/types";

function formatWhen(iso: string) {
  return new Date(iso).toLocaleString("en-PK", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function TaskDetailModal({
  task,
  projectId,
  members,
  onClose,
}: {
  task: ProjectTask;
  projectId: string;
  members: ProjectPerson[];
  onClose: () => void;
}) {
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-lg overflow-y-auto border border-outline-variant bg-surface p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-[16px] font-semibold text-on-surface">{task.title}</h2>
            <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              {task.status.replace("_", " ")}
              {task.dueDate && (
                <span className={overdue ? "ml-2 text-error" : "ml-2"}>
                  · {formatRelativeDate(task.dueDate).label}
                </span>
              )}
            </p>
          </div>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-on-surface-variant hover:text-on-surface"
          >
            <X size={18} />
          </button>
        </div>

        {task.description && (
          <p className="mt-3 text-[13px] leading-6 text-on-surface-variant">{task.description}</p>
        )}

        <form action={updateTask} className="mt-4 space-y-3 border-t border-outline-variant pt-4">
          <input type="hidden" name="taskId" value={task.id} />
          <input type="hidden" name="projectId" value={projectId} />

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Title
            </label>
            <input
              type="text"
              name="title"
              defaultValue={task.title}
              required
              className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[13px] focus:border-primary focus:outline-none"
            />
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Description
            </label>
            <textarea
              name="description"
              rows={3}
              defaultValue={task.description ?? ""}
              placeholder="Optional"
              className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Priority
              </label>
              <select
                name="priority"
                defaultValue={task.priority}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="urgent">Urgent</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                Due date
              </label>
              <input
                type="date"
                name="dueDate"
                defaultValue={task.dueDate ?? ""}
                className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Labels
            </label>
            <div className="flex flex-wrap gap-2">
              {TASK_LABELS.map((label) => (
                <label
                  key={label}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input
                    type="checkbox"
                    name="labels"
                    value={label}
                    defaultChecked={task.labels.includes(label)}
                  />
                  {label}
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
              Assignees
            </label>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <label
                  key={m.id}
                  className="flex items-center gap-1.5 border border-outline-variant px-2 py-1 text-[11px] text-on-surface-variant"
                >
                  <input
                    type="checkbox"
                    name="assigneeIds"
                    value={m.id}
                    defaultChecked={task.assignees.some((a) => a.id === m.id)}
                  />
                  {m.fullName ?? "Unnamed"}
                </label>
              ))}
              {members.length === 0 && (
                <p className="text-[11px] text-on-surface-variant/60">No project members yet.</p>
              )}
            </div>
          </div>

          <button
            type="submit"
            className="w-full bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            Save changes
          </button>
        </form>

        <div className="mt-5 border-t border-outline-variant pt-4">
          <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
            Comments
          </p>
          <div className="mt-2 max-h-40 space-y-2 overflow-y-auto">
            {task.comments.length === 0 && (
              <p className="text-[12px] text-on-surface-variant/60">No comments yet.</p>
            )}
            {task.comments.map((c) => (
              <div key={c.id} className="border-l-2 border-outline-variant pl-2">
                <div className="flex items-baseline gap-2">
                  <span className="text-[12px] font-semibold text-on-surface">
                    {c.authorName ?? "Someone"}
                  </span>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/60">
                    {formatWhen(c.createdAt)}
                  </span>
                </div>
                <p className="text-[12px] text-on-surface-variant">{c.body}</p>
              </div>
            ))}
          </div>

          <form action={addTaskComment} className="mt-3 flex gap-2">
            <input type="hidden" name="taskId" value={task.id} />
            <input type="hidden" name="projectId" value={projectId} />
            <input
              name="body"
              required
              placeholder="Add a comment…"
              className="flex-1 border border-outline-variant bg-background px-2 py-1.5 text-[12px] focus:border-primary focus:outline-none"
            />
            <button
              type="submit"
              className="bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
            >
              Post
            </button>
          </form>
        </div>

        <div className="mt-5 border-t border-outline-variant pt-4">
          {!confirmingDelete ? (
            <button
              onClick={() => setConfirmingDelete(true)}
              className="flex items-center gap-2 font-mono-data text-[11px] uppercase tracking-wider text-error hover:underline"
            >
              <Trash2 size={13} />
              Delete task
            </button>
          ) : (
            <form action={deleteTask} className="flex items-center gap-2">
              <input type="hidden" name="taskId" value={task.id} />
              <input type="hidden" name="projectId" value={projectId} />
              <span className="text-[11px] text-error">Delete this task permanently?</span>
              <button
                type="submit"
                className="bg-error px-2 py-1 font-mono-data text-[10px] uppercase tracking-wider text-white transition hover:brightness-110"
              >
                Confirm
              </button>
              <button
                type="button"
                onClick={() => setConfirmingDelete(false)}
                className="text-[10px] text-on-surface-variant hover:text-on-surface"
              >
                Cancel
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
TASKMODAL_EOF

cat > src/components/projects/task-board.tsx << 'TASKBOARD_EOF'
"use client";

import { useState } from "react";
import {
  DndContext,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import { Plus } from "lucide-react";
import { cn, formatRelativeDate } from "@/lib/utils";
import { StatusPill } from "@/components/ui/status-pill";
import { moveTask } from "@/app/(dashboard)/projects/actions";
import { AddTaskForm } from "@/components/projects/add-task-form";
import { TaskDetailModal } from "@/components/projects/task-detail-modal";
import type { ProjectPerson, ProjectTask, TaskStatus } from "@/lib/types";
import { TASK_LABELS } from "@/lib/types";

const COLUMNS: { id: TaskStatus; label: string }[] = [
  { id: "backlog", label: "Backlog" },
  { id: "todo", label: "To Do" },
  { id: "in_progress", label: "In Progress" },
  { id: "review", label: "Review" },
  { id: "done", label: "Done" },
];

const PRIORITY_TONE: Record<string, "neutral" | "primary" | "warning" | "error"> = {
  low: "neutral",
  medium: "primary",
  high: "warning",
  urgent: "error",
};

function initials(name: string | null) {
  if (!name) return "?";
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function TaskCard({ task, onOpen }: { task: ProjectTask; onOpen: (task: ProjectTask) => void }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: task.id,
  });

  const style = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` }
    : undefined;

  const overdue =
    task.status !== "done" && !!task.dueDate && formatRelativeDate(task.dueDate).daysUntil < 0;

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      onClick={() => onOpen(task)}
      role="button"
      tabIndex={0}
      className={cn(
        "cursor-grab select-none border border-outline-variant bg-surface p-3 text-left transition active:cursor-grabbing",
        isDragging ? "z-50 opacity-70 shadow-lg" : "hover:border-primary/40"
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-[13px] font-medium leading-snug text-on-surface">{task.title}</p>
        <StatusPill tone={PRIORITY_TONE[task.priority]} className="shrink-0">
          {task.priority}
        </StatusPill>
      </div>

      {task.labels.length > 0 && (
        <div className="mt-1.5 flex flex-wrap gap-1">
          {task.labels.map((label) => (
            <span
              key={label}
              className="border border-outline-variant bg-surface-container-high/60 px-1.5 py-0.5 font-mono-data text-[9px] uppercase tracking-wider text-on-surface-variant"
            >
              {label}
            </span>
          ))}
        </div>
      )}

      {task.dueDate && (
        <p
          className={cn(
            "mt-2 font-mono-data text-[10px] uppercase tracking-wider",
            overdue ? "text-error" : "text-on-surface-variant"
          )}
        >
          {formatRelativeDate(task.dueDate).label}
        </p>
      )}

      <div className="mt-2 flex items-center justify-between">
        <div className="flex flex-wrap gap-1">
          {task.assignees.map((a) => (
            <span
              key={a.id}
              title={a.fullName ?? "Unnamed"}
              className="flex h-5 w-5 items-center justify-center border border-outline-variant bg-background font-mono-data text-[9px] text-on-surface-variant"
            >
              {initials(a.fullName)}
            </span>
          ))}
        </div>
        {task.comments.length > 0 && (
          <span className="font-mono-data text-[10px] text-on-surface-variant/60">
            {task.comments.length} comment{task.comments.length === 1 ? "" : "s"}
          </span>
        )}
      </div>
    </div>
  );
}

function Column({
  id,
  label,
  tasks,
  onOpen,
}: {
  id: TaskStatus;
  label: string;
  tasks: ProjectTask[];
  onOpen: (task: ProjectTask) => void;
}) {
  const { setNodeRef, isOver } = useDroppable({ id });

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex w-[260px] shrink-0 flex-col border border-outline-variant bg-background",
        isOver && "border-primary/60 bg-primary/[0.03]"
      )}
    >
      <div className="flex items-center justify-between border-b border-outline-variant px-3 py-2">
        <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          {label}
        </span>
        <span className="font-mono-data text-[10px] text-on-surface-variant/60">
          {tasks.length}
        </span>
      </div>
      <div className="min-h-[140px] flex-1 space-y-2 overflow-y-auto p-2">
        {tasks.map((task) => (
          <TaskCard key={task.id} task={task} onOpen={onOpen} />
        ))}
        {tasks.length === 0 && (
          <p className="p-3 text-center text-[11px] text-on-surface-variant/50">No tasks</p>
        )}
      </div>
    </div>
  );
}

export function TaskBoard({
  projectId,
  initialTasks,
  members,
}: {
  projectId: string;
  initialTasks: ProjectTask[];
  members: ProjectPerson[];
}) {
  const [tasks, setTasks] = useState(initialTasks);
  const [activeTask, setActiveTask] = useState<ProjectTask | null>(null);
  const [addingTask, setAddingTask] = useState(false);
  const [filterAssignee, setFilterAssignee] = useState("");
  const [filterPriority, setFilterPriority] = useState("");
  const [filterLabel, setFilterLabel] = useState("");

  // Server actions revalidate the page instead of redirecting (so the
  // board and any open task panel can update in place). When a fresh
  // `initialTasks` comes down from the server, sync local state from it —
  // computed during render (not in an effect) per React's guidance on
  // adjusting state from changed props.
  const [syncedTasks, setSyncedTasks] = useState(initialTasks);
  if (initialTasks !== syncedTasks) {
    setSyncedTasks(initialTasks);
    setTasks(initialTasks);
    setActiveTask((prev) => (prev ? initialTasks.find((t) => t.id === prev.id) ?? null : null));
  }

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } })
  );

  const visibleTasks = tasks.filter((t) => {
    if (filterAssignee && !t.assignees.some((a) => a.id === filterAssignee)) return false;
    if (filterPriority && t.priority !== filterPriority) return false;
    if (filterLabel && !t.labels.includes(filterLabel)) return false;
    return true;
  });
  const filtersActive = !!(filterAssignee || filterPriority || filterLabel);

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;

    const taskId = String(active.id);
    const newStatus = over.id as TaskStatus;
    const task = tasks.find((t) => t.id === taskId);
    if (!task || task.status === newStatus) return;

    const updated = tasks.map((t) => (t.id === taskId ? { ...t, status: newStatus } : t));
    setTasks(updated);

    const destinationIds = updated.filter((t) => t.status === newStatus).map((t) => t.id);
    void moveTask(taskId, projectId, newStatus, destinationIds);
  }

  return (
    <div>
      <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
          Drag a card to change its status
        </p>
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={filterAssignee}
            onChange={(e) => setFilterAssignee(e.target.value)}
            className="border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[11px] text-on-surface-variant focus:border-primary focus:outline-none"
          >
            <option value="">All assignees</option>
            {members.map((m) => (
              <option key={m.id} value={m.id}>
                {m.fullName ?? "Unnamed"}
              </option>
            ))}
          </select>
          <select
            value={filterPriority}
            onChange={(e) => setFilterPriority(e.target.value)}
            className="border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[11px] text-on-surface-variant focus:border-primary focus:outline-none"
          >
            <option value="">All priorities</option>
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
            <option value="urgent">Urgent</option>
          </select>
          <select
            value={filterLabel}
            onChange={(e) => setFilterLabel(e.target.value)}
            className="border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[11px] text-on-surface-variant focus:border-primary focus:outline-none"
          >
            <option value="">All labels</option>
            {TASK_LABELS.map((label) => (
              <option key={label} value={label}>
                {label}
              </option>
            ))}
          </select>
          {filtersActive && (
            <button
              type="button"
              onClick={() => {
                setFilterAssignee("");
                setFilterPriority("");
                setFilterLabel("");
              }}
              className="font-mono-data text-[11px] uppercase tracking-wider text-primary hover:underline"
            >
              Clear
            </button>
          )}
          <button
            onClick={() => setAddingTask(true)}
            className="flex items-center gap-1.5 bg-primary px-3 py-1.5 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
          >
            <Plus size={13} />
            Add task
          </button>
        </div>
      </div>

      {filtersActive && (
        <p className="mb-2 text-[11px] text-on-surface-variant">
          Showing {visibleTasks.length} of {tasks.length} tasks
        </p>
      )}

      <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
        <div className="flex gap-3 overflow-x-auto pb-2">
          {COLUMNS.map((col) => (
            <Column
              key={col.id}
              id={col.id}
              label={col.label}
              tasks={visibleTasks.filter((t) => t.status === col.id)}
              onOpen={setActiveTask}
            />
          ))}
        </div>
      </DndContext>

      {activeTask && (
        <TaskDetailModal
          task={activeTask}
          projectId={projectId}
          members={members}
          onClose={() => setActiveTask(null)}
        />
      )}

      {addingTask && (
        <AddTaskForm projectId={projectId} members={members} onClose={() => setAddingTask(false)} />
      )}
    </div>
  );
}
TASKBOARD_EOF

echo "==> Step 3/3: writing the schema migration"
mkdir -p supabase
cat > supabase/schema-phase7-projects-upgrades.sql << 'SCHEMA_EOF'
-- Sanestix OS — Phase 7: Projects/Tasks upgrades (Jira/ClickUp-style).
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is ADD COLUMN IF NOT EXISTS / CREATE INDEX IF NOT EXISTS.
--
-- Adds:
--   tasks.labels — a small set of free-form tags per task (e.g. "Bug",
--   "Feature", "Client Request"), filterable on the Kanban board.

alter table public.tasks add column if not exists labels text[] not null default '{}'::text[];
create index if not exists tasks_labels_idx on public.tasks using gin (labels);
SCHEMA_EOF

echo ""
echo "Done writing files."
echo ""
echo "IMPORTANT — one manual step: run supabase/schema-phase7-projects-upgrades.sql"
echo "in your Supabase project's SQL editor (adds the tasks.labels column)."
echo "The app will build and run without it, but labels won't persist until"
echo "that column exists."
echo ""
echo "Then rebuild and restart:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
