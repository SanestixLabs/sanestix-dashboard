import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getProjects } from "@/lib/supabase/queries";
import { addProject, updateProjectStatus, deleteProject } from "@/app/projects/actions";
import type { ProjectRowStatus } from "@/lib/types";

export const dynamic = "force-dynamic";

const STATUS_OPTIONS: { value: ProjectRowStatus; label: string }[] = [
  { value: "on_track", label: "On Track" },
  { value: "at_risk", label: "At Risk" },
  { value: "delayed", label: "Delayed" },
  { value: "completed", label: "Completed" },
];

const STATUS_TONE: Record<ProjectRowStatus, "success" | "warning" | "error" | "neutral"> = {
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
  const projects = await getProjects();
  const activeCount = projects.filter((p) => p.status !== "completed").length;
  const atRiskCount = projects.filter((p) => p.status === "at_risk" || p.status === "delayed").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "Projects"]}>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Projects</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Client delivery work. Projects marked with a source lead were auto-created when that
          lead was won in CRM.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
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
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Add a project</CardTitle>
          <CardDescription>Manually start a project not tied to a CRM lead.</CardDescription>

          <form action={addProject} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}
            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Project name
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
                Client name
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
                Notes
              </label>
              <textarea
                name="notes"
                rows={3}
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="Optional"
              />
            </div>
            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add project
            </button>
          </form>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Project List</CardTitle>
          <CardDescription>All projects, newest first.</CardDescription>

          <div className="mt-4 max-h-[560px] overflow-auto">
            <table className="w-full min-w-[720px] text-left text-[13px]">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
                  <th className="pb-2 pr-4">Name</th>
                  <th className="pb-2 pr-4">Client / Company</th>
                  <th className="pb-2 pr-4">Source</th>
                  <th className="pb-2 pr-4">Status</th>
                  <th className="pb-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {projects.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-6 text-center text-on-surface-variant">
                      No projects yet. Add one above, or win a lead in CRM.
                    </td>
                  </tr>
                )}
                {projects.map((p) => (
                  <tr key={p.id} className="border-b border-outline-variant/50">
                    <td className="py-2.5 pr-4 text-on-surface">{p.name}</td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.clientName ?? p.companyName ?? "—"}
                    </td>
                    <td className="py-2.5 pr-4 text-on-surface-variant">
                      {p.sourceLeadId ? (
                        <Link
                          href={`/crm/leads/${p.sourceLeadId}`}
                          className="text-primary hover:underline"
                        >
                          {p.sourceLeadTitle ?? "CRM lead"}
                        </Link>
                      ) : (
                        "Manual"
                      )}
                    </td>
                    <td className="py-2.5">
                      <RegisterStatusForm
                        idFieldName="projectId"
                        idValue={p.id}
                        status={p.status}
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
    </DashboardShell>
  );
}
