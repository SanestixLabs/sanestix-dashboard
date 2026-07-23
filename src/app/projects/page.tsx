import { ModuleFoundation } from "@/components/modules/module-foundation";

export const dynamic = "force-dynamic";

export default function ProjectsPage() {
  return (
    <ModuleFoundation
      title="Projects"
      eyebrow="Phase 1.3"
      breadcrumb={["Sanestix OS", "Projects"]}
      description="Project management should become the daily workspace for client delivery: project list, Kanban, task ownership, deadlines, and overdue visibility."
      readyItems={[
        "Authenticated app shell and protected routing are already active.",
        "Dashboard has a project KPI and status chart placeholder ready for real data.",
        "Mobile navigation now supports field use on phones and tablets.",
      ]}
      nextItems={[
        "Create Supabase tables for projects, project_members, tasks, comments, and activity.",
        "Ship a Kanban board with task status, assignee, priority, and due date.",
        "Add overdue task notifications and dashboard rollups from live task data.",
      ]}
    />
  );
}
