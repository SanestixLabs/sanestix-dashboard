import Link from "next/link";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { RegisterStatusForm } from "@/components/finance/register-status-form";
import { RegisterDeleteButton } from "@/components/finance/register-delete-button";
import { getCrmLeads, getCrmCompanies, getCrmContacts } from "@/lib/supabase/queries";
import { addLead, updateLeadStage, deleteLead } from "@/app/crm/actions";
import { LEAD_STAGES, type LeadStage } from "@/lib/types";
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

const BOARD_STAGES = LEAD_STAGES.filter((s) => s.value !== "lost");

export default async function CrmPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const [leads, companies, contacts] = await Promise.all([
    getCrmLeads(),
    getCrmCompanies(),
    getCrmContacts(),
  ]);

  const openLeads = leads.filter((l) => l.stage !== "won" && l.stage !== "lost");
  const pipelineValue = openLeads.reduce((sum, l) => sum + l.value, 0);
  const wonThisMonth = leads.filter((l) => {
    if (l.stage !== "won") return false;
    const d = new Date(l.updatedAt);
    const now = new Date();
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  }).length;
  const lostCount = leads.filter((l) => l.stage === "lost").length;

  return (
    <DashboardShell breadcrumb={["Sanestix OS", "CRM"]}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-[28px] font-bold tracking-tight text-on-surface">CRM Pipeline</h1>
          <p className="mt-1 text-[13px] text-on-surface-variant">
            Leads from intake to closed work. Moving a lead to Won creates a draft project
            automatically.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Open leads
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-primary">{openLeads.length}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Pipeline value
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-success">
            {formatCurrency(pipelineValue)}
          </p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Won this month
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight">{wonThisMonth}</p>
        </Card>
        <Card className="p-4">
          <p className="text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
            Lost
          </p>
          <p className="mt-2 text-[22px] font-bold tracking-tight text-on-surface-variant">
            {lostCount}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
        <Card className="p-6 lg:col-span-1">
          <CardTitle>Add a lead</CardTitle>
          <CardDescription>New pipeline entry, starts at stage &quot;New&quot;.</CardDescription>

          <form action={addLead} className="mt-4 space-y-3">
            {params.error && (
              <div className="border border-error/30 bg-error-tint px-3 py-2 text-[12px] text-error">
                {params.error}
              </div>
            )}

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Lead title
              </label>
              <input
                type="text"
                name="title"
                required
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Marwaa Memorials — Website"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Company
              </label>
              <select
                name="companyId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
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
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Contact
              </label>
              <select
                name="contactId"
                defaultValue=""
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              >
                <option value="">— None —</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.fullName}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Deal value (PKR)
              </label>
              <input
                type="number"
                name="value"
                min="0"
                step="0.01"
                defaultValue="0"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Source
              </label>
              <input
                type="text"
                name="source"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
                placeholder="e.g. Website form, referral"
              />
            </div>

            <div>
              <label className="mb-1 block font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                Expected close date
              </label>
              <input
                type="date"
                name="expectedCloseDate"
                className="w-full border border-outline-variant bg-background px-3 py-2 font-mono-data text-[13px] focus:border-primary focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
            >
              Add lead
            </button>
          </form>

          <div className="mt-6 flex flex-col gap-2 border-t border-outline-variant pt-4 text-[11px]">
            <Link href="/crm/companies" className="text-on-surface-variant hover:text-primary">
              Manage companies →
            </Link>
            <Link href="/crm/contacts" className="text-on-surface-variant hover:text-primary">
              Manage contacts →
            </Link>
            <Link href="/crm/tasks" className="text-on-surface-variant hover:text-primary">
              Follow-up tasks →
            </Link>
          </div>
        </Card>

        <div className="lg:col-span-3">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {BOARD_STAGES.map((stage) => {
              const stageLeads = leads.filter((l) => l.stage === stage.value);
              return (
                <div key={stage.value} className="flex min-w-0 flex-col">
                  <div className="mb-2 flex items-center justify-between px-1">
                    <span className="font-mono-data text-[11px] uppercase tracking-wider text-on-surface-variant">
                      {stage.label}
                    </span>
                    <span className="font-mono-data text-[11px] text-on-surface-variant/70">
                      {stageLeads.length}
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-2">
                    {stageLeads.length === 0 && (
                      <Card className="p-3 text-center text-[11px] text-on-surface-variant/60">
                        Empty
                      </Card>
                    )}
                    {stageLeads.map((lead) => (
                      <Card key={lead.id} className="p-3">
                        <Link
                          href={`/crm/leads/${lead.id}`}
                          className="block text-[13px] font-medium text-on-surface hover:text-primary"
                        >
                          {lead.title}
                        </Link>
                        <p className="mt-0.5 truncate text-[11px] text-on-surface-variant">
                          {lead.companyName ?? lead.contactName ?? "—"}
                        </p>
                        <p className="mt-1 font-mono-data text-[12px] font-semibold text-success">
                          {formatCurrency(lead.value)}
                        </p>
                        {lead.overdueTaskCount > 0 && (
                          <p className="mt-1 font-mono-data text-[10px] uppercase tracking-wider text-error">
                            {lead.overdueTaskCount} overdue task{lead.overdueTaskCount > 1 ? "s" : ""}
                          </p>
                        )}
                        <div className="mt-2 flex items-center justify-between gap-2">
                          <RegisterStatusForm
                            idFieldName="leadId"
                            idValue={lead.id}
                            status={lead.stage}
                            tone={STAGE_TONE[lead.stage]}
                            options={LEAD_STAGES.map((s) => ({ value: s.value, label: s.label }))}
                            action={updateLeadStage}
                            extraFields={{ redirectTo: "/crm" }}
                          />
                          <RegisterDeleteButton
                            action={deleteLead}
                            idFieldName="leadId"
                            idValue={lead.id}
                            redirectTo="/crm"
                            label="lead"
                          />
                        </div>
                      </Card>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </DashboardShell>
  );
}
