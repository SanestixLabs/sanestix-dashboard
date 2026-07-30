import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { SetBreadcrumb } from "@/components/layout/breadcrumb-context";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { MemberPicker } from "@/components/projects/member-picker";
import { TaskBoard } from "@/components/projects/task-board";
import {
  getProjectById,
  getProjectMembers,
  getProjectTasks,
  getFounders,
} from "@/lib/supabase/queries";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STATUS_LABEL: Record<string, string> = {
  on_track: "On Track",
  at_risk: "At Risk",
  delayed: "Delayed",
  completed: "Completed",
};

const STATUS_TONE: Record<string, "success" | "warning" | "error" | "neutral"> = {
  on_track: "success",
  at_risk: "warning",
  delayed: "error",
  completed: "neutral",
};

export default async function ProjectDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const project = await getProjectById(id);
  if (!project) notFound();

  const [members, tasks, everyone] = await Promise.all([
    getProjectMembers(id),
    getProjectTasks(id),
    getFounders(),
  ]);

  return (
    <>
    <SetBreadcrumb crumbs={["Sanestix OS", "Projects", project.name]} />
      <div>
        <Link
          href="/projects"
          className="inline-flex items-center gap-1.5 font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant hover:text-on-surface"
        >
          <ArrowLeft size={13} />
          All projects
        </Link>

        <div className="mt-2 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-[28px] font-bold tracking-tight text-on-surface">{project.name}</h1>
            <p className="mt-1 text-[13px] text-on-surface-variant">
              {project.clientName ? `Client: ${project.clientName}` : "No client set"}
              {project.ownerName ? ` · Owner: ${project.ownerName}` : ""}
            </p>
          </div>
          <StatusPill tone={STATUS_TONE[project.status]}>
            {STATUS_LABEL[project.status] ?? project.status}
          </StatusPill>
        </div>

        {project.description && (
          <p className="mt-3 max-w-2xl text-[13px] leading-6 text-on-surface-variant">
            {project.description}
          </p>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Tasks
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">
            {project.doneTaskCount}/{project.taskCount}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">
            {project.overdueTaskCount}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Budget
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">
            {project.budget !== null ? formatCurrency(project.budget) : "—"}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Timeline
          </p>
          <p className="mt-2 font-mono-data text-[12px] text-on-surface">
            {project.startDate ?? "—"} → {project.endDate ?? "—"}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <div className="lg:col-span-3">
          <Card className="p-6">
            <CardTitle>Kanban</CardTitle>
            <CardDescription>Drag a card between columns to update its status.</CardDescription>
            <div className="mt-4">
              <TaskBoard projectId={id} initialTasks={tasks} members={members} />
            </div>
          </Card>
        </div>
        <div className="lg:col-span-1">
          <MemberPicker projectId={id} members={members} everyone={everyone} />
        </div>
      </div>
    </>
  );
}
