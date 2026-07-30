import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { SetBreadcrumb } from "@/components/layout/breadcrumb-context";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { StatusPill } from "@/components/ui/status-pill";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { TaskToggleCheckbox } from "@/components/crm/task-toggle-checkbox";
import { EditToggle } from "@/components/crm/edit-toggle";
import {
  getCrmLead,
  getLeadActivities,
  getOpenLeadTasks,
  getCrmCompanies,
  getCrmContacts,
} from "@/lib/supabase/queries";
import {
  updateLead,
  updateLeadStage,
  updateLeadLostReason,
  deleteLead,
  addLeadNote,
  addLeadTask,
  toggleLeadTask,
  deleteLeadTask,
} from "@/app/(dashboard)/crm/actions";
import { LEAD_STAGES, LOST_REASONS, type LeadStage } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

const ACTIVITY_LABEL: Record<string, string> = {
  note: "Note",
  call: "Call",
  email: "Email",
  meeting: "Meeting",
  stage_change: "Stage change",
};

export default async function LeadDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { id } = await params;
  const search = await searchParams;
  const lead = await getCrmLead(id);
  if (!lead) notFound();

  const [activities, allOpenTasks, companies, contacts] = await Promise.all([
    getLeadActivities(id),
    getOpenLeadTasks(),
    getCrmCompanies(),
    getCrmContacts(),
  ]);
  const leadTasks = allOpenTasks.filter((t) => t.leadId === id);
  const redirectTo = `/crm/leads/${id}`;

  return (
    <>
    <SetBreadcrumb crumbs={["Sanestix OS", "CRM", lead.title]} />
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <Link href="/crm" className="text-[11px] text-on-surface-variant hover:text-primary">
            ← Back to pipeline
          </Link>
          <h1 className="mt-2 text-[28px] font-bold tracking-tight text-on-surface">{lead.title}</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            {lead.companyName ?? "No company"} · {lead.contactName ?? "No contact"}
          </p>
        </div>
        <RegisterDeleteButton
          action={deleteLead}
          idFieldName="leadId"
          idValue={lead.id}
          redirectTo="/crm"
          label="lead"
        />
      </div>

      {lead.convertedProjectId && (
        <Card className="flex items-center justify-between border-success/30 bg-success/[0.06] p-4">
          <p className="text-[13px] text-on-surface">
            This lead was won and auto-created a draft project.
          </p>
          <Link
            href="/projects"
            className="inline-flex items-center gap-1 text-[12px] font-mono-data uppercase tracking-wider text-success hover:brightness-110"
          >
            View project <ArrowRight size={14} />
          </Link>
        </Card>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="p-6">
          <CardTitle>Details</CardTitle>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Stage</span>
              <RegisterStatusForm
                idFieldName="leadId"
                idValue={lead.id}
                status={lead.stage}
                tone={STAGE_TONE[lead.stage]}
                options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                action={updateLeadStage}
                extraFields={{ redirectTo }}
              />
            </div>
            {lead.stage === "lost" && (
              <div className="flex items-center justify-between gap-3">
                <span className="text-on-surface-variant">Lost reason</span>
                <span className="text-right text-on-surface">{lead.lostReason ?? "—"}</span>
              </div>
            )}
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Value</span>
              <span className="font-mono-data font-semibold text-success">
                {formatCurrency(lead.value)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Owner</span>
              <span className="text-on-surface">{lead.ownerName ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Source</span>
              <span className="text-on-surface">{lead.source ?? "—"}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Expected close</span>
              <span className="font-mono-data text-on-surface">
                {lead.expectedCloseDate
                  ? new Date(lead.expectedCloseDate).toLocaleDateString()
                  : "—"}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-on-surface-variant">Contact email</span>
              <span className="text-on-surface">{lead.contactEmail ?? "—"}</span>
            </div>
            {lead.notes && (
              <div className="border-t border-outline-variant pt-3">
                <span className="text-on-surface-variant">Notes</span>
                <p className="mt-1 text-on-surface">{lead.notes}</p>
              </div>
            )}
          </div>

          {lead.stage === "lost" && (
            <div className="mt-4 border-t border-outline-variant pt-4">
              <EditToggle label={lead.lostReason ? "Change lost reason" : "Set lost reason"}>
                <form action={updateLeadLostReason} className="space-y-2">
                  <input type="hidden" name="leadId" value={lead.id} />
                  <input type="hidden" name="redirectTo" value={redirectTo} />
                  <select
                    name="lostReason"
                    defaultValue={lead.lostReason ?? ""}
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  >
                    <option value="">— No reason —</option>
                    {LOST_REASONS.map((reason) => (
                      <option key={reason} value={reason}>
                        {reason}
                      </option>
                    ))}
                  </select>
                  <button
                    type="submit"
                    className="w-full bg-primary px-3 py-1.5 font-mono-data text-[10px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
                  >
                    Save
                  </button>
                </form>
              </EditToggle>
            </div>
          )}

          <div className="mt-4 border-t border-outline-variant pt-4">
            <EditToggle label="Edit lead details">
              <form action={updateLead} className="space-y-2.5">
                <input type="hidden" name="leadId" value={lead.id} />
                <input type="hidden" name="redirectTo" value={redirectTo} />
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Title
                  </label>
                  <input
                    name="title"
                    defaultValue={lead.title}
                    required
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Company
                    </label>
                    <select
                      name="companyId"
                      defaultValue={lead.companyId ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    >
                      <option value="">— None —</option>
                      {companies.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Contact
                    </label>
                    <select
                      name="contactId"
                      defaultValue={lead.contactId ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    >
                      <option value="">— None —</option>
                      {contacts.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.fullName}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Value (PKR)
                    </label>
                    <input
                      name="value"
                      type="number"
                      min="0"
                      step="0.01"
                      defaultValue={lead.value}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                      Expected close
                    </label>
                    <input
                      name="expectedCloseDate"
                      type="date"
                      defaultValue={lead.expectedCloseDate ?? ""}
                      className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                    />
                  </div>
                </div>
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Source
                  </label>
                  <input
                    name="source"
                    defaultValue={lead.source ?? ""}
                    placeholder="e.g. Referral, Website, LinkedIn"
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block font-mono-data text-[10px] uppercase tracking-wider text-on-surface-variant">
                    Notes
                  </label>
                  <textarea
                    name="notes"
                    rows={2}
                    defaultValue={lead.notes ?? ""}
                    className="w-full border border-outline-variant bg-background px-2 py-1.5 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                  />
                </div>
                <button
                  type="submit"
                  className="w-full bg-primary px-3 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary transition hover:brightness-110"
                >
                  Save changes
                </button>
              </form>
            </EditToggle>
          </div>

          <div className="mt-6 border-t border-outline-variant pt-4">
            <CardTitle>Follow-up tasks</CardTitle>
            <div className="mt-3 space-y-2">
              {leadTasks.length === 0 && (
                <p className="text-[12px] text-on-surface-variant">No open tasks.</p>
              )}
              {leadTasks.map((t) => (
                <div key={t.id} className="flex items-center gap-2 text-[12px]">
                  <TaskToggleCheckbox
                    action={toggleLeadTask}
                    taskId={t.id}
                    done={t.done}
                    redirectTo={redirectTo}
                  />
                  <span className="min-w-0 flex-1 truncate text-on-surface">{t.title}</span>
                  <StatusPill tone={t.overdue ? "error" : "neutral"}>
                    {new Date(t.dueDate).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                    })}
                  </StatusPill>
                  <form action={deleteLeadTask}>
                    <input type="hidden" name="taskId" value={t.id} />
                    <input type="hidden" name="redirectTo" value={redirectTo} />
                    <button
                      type="submit"
                      aria-label="Delete task"
                      className="text-on-surface-variant hover:text-error"
                    >
                      ✕
                    </button>
                  </form>
                </div>
              ))}
            </div>

            <form action={addLeadTask} className="mt-3 flex flex-col gap-2">
              <input type="hidden" name="leadId" value={lead.id} />
              <input type="hidden" name="redirectTo" value={redirectTo} />
              <input
                type="text"
                name="title"
                required
                placeholder="e.g. Call back Thursday"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
              <div className="flex gap-2">
                <input
                  type="date"
                  name="dueDate"
                  required
                  className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
                />
                <button
                  type="submit"
                  className="bg-primary px-3 py-2 font-mono-data text-[10px] uppercase tracking-wider text-on-primary hover:brightness-110"
                >
                  Add
                </button>
              </div>
            </form>
          </div>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <CardTitle>Activity</CardTitle>
          <CardDescription>Notes, calls, emails, meetings, and stage changes.</CardDescription>

          <form action={addLeadNote} className="mt-4 space-y-2 border-b border-outline-variant pb-4">
            <input type="hidden" name="leadId" value={lead.id} />
            {search.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {search.error}
              </div>
            )}
            <div className="flex gap-2">
              <select
                name="kind"
                defaultValue="note"
                className="border border-outline-variant bg-background px-2 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              >
                <option value="note">Note</option>
                <option value="call">Call</option>
                <option value="email">Email</option>
                <option value="meeting">Meeting</option>
              </select>
              <textarea
                name="content"
                required
                rows={2}
                placeholder="What happened?"
                className="flex-1 border border-outline-variant bg-background px-3 py-2 font-mono-data text-[12px] focus:border-primary focus:outline-none"
              />
            </div>
            <button
              type="submit"
              className="bg-primary px-4 py-2 font-mono-data text-[11px] uppercase tracking-wider text-on-primary hover:brightness-110"
            >
              Log activity
            </button>
          </form>

          <div className="mt-4 max-h-[520px] space-y-4 overflow-auto">
            {activities.length === 0 && (
              <p className="py-6 text-center text-[13px] text-on-surface-variant">
                No activity logged yet.
              </p>
            )}
            {activities.map((a) => (
              <div key={a.id} className="border-l-2 border-outline-variant pl-3">
                <div className="flex items-center gap-2">
                  <StatusPill tone={a.kind === "stage_change" ? "primary" : "neutral"}>
                    {ACTIVITY_LABEL[a.kind] ?? a.kind}
                  </StatusPill>
                  <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                    {new Date(a.createdAt).toLocaleString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </span>
                  {a.createdByName && (
                    <span className="font-mono-data text-[10px] text-on-surface-variant/70">
                      · {a.createdByName}
                    </span>
                  )}
                </div>
                <p className="mt-1 text-[13px] text-on-surface">{a.content}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}
