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
