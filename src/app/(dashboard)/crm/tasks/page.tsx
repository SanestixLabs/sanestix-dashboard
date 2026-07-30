import Link from "next/link";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { TaskToggleCheckbox } from "@/components/crm/task-toggle-checkbox";
import { getOpenLeadTasks } from "@/lib/supabase/queries";
import { toggleLeadTask, deleteLeadTask } from "@/app/(dashboard)/crm/actions";

export const dynamic = "force-dynamic";

export default async function CrmTasksPage() {
  const tasks = await getOpenLeadTasks();
  const overdueTasks = tasks.filter((t) => t.overdue);
  const upcomingTasks = tasks.filter((t) => !t.overdue);

  return (
    <>
      <div>
        <h1 className="text-[28px] font-bold tracking-tight text-on-surface">Follow-up Tasks</h1>
        <p className="mt-1 text-[13px] text-on-surface-variant">
          Every open reminder across your pipeline, soonest due first.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Overdue
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-error">{overdueTasks.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Upcoming
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{upcomingTasks.length}</p>
        </Card>
      </div>

      <Card className="p-6">
        <CardTitle>All open tasks</CardTitle>
        <CardDescription>Check one off to mark it done, or delete it.</CardDescription>

        <div className="mt-4 divide-y divide-outline-variant">
          {tasks.length === 0 && (
            <p className="py-6 text-center text-[13px] text-on-surface-variant">
              No open follow-up tasks. Add one from a lead&apos;s detail page.
            </p>
          )}
          {tasks.map((t) => (
            <div key={t.id} className="flex items-center gap-3 py-3">
              <TaskToggleCheckbox
                action={toggleLeadTask}
                taskId={t.id}
                done={t.done}
                redirectTo="/crm/tasks"
              />
              <div className="min-w-0 flex-1">
                <p className="truncate text-[13px] text-on-surface">{t.title}</p>
                {t.leadId && (
                  <Link
                    href={`/crm/leads/${t.leadId}`}
                    className="text-[11px] text-on-surface-variant hover:text-primary"
                  >
                    {t.leadTitle ?? "View lead"} →
                  </Link>
                )}
              </div>
              <StatusPill tone={t.overdue ? "error" : "neutral"}>
                {new Date(t.dueDate).toLocaleDateString(undefined, {
                  month: "short",
                  day: "numeric",
                })}
              </StatusPill>
              <form action={deleteLeadTask}>
                <input type="hidden" name="taskId" value={t.id} />
                <input type="hidden" name="redirectTo" value="/crm/tasks" />
                <button
                  type="submit"
                  aria-label="Delete task"
                  className="px-1.5 py-1 text-on-surface-variant transition hover:text-error"
                >
                  ✕
                </button>
              </form>
            </div>
          ))}
        </div>
      </Card>
    </>
  );
}
