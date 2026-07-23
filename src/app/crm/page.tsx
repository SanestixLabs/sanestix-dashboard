import { ModuleFoundation } from "@/components/modules/module-foundation";

export const dynamic = "force-dynamic";

export default function CrmPage() {
  return (
    <ModuleFoundation
      title="CRM"
      eyebrow="Phase 1.4"
      breadcrumb={["Sanestix OS", "CRM"]}
      description="The CRM module should track leads from intake to closed work, with notes, ownership, pipeline value, and outreach metrics connected to the executive dashboard."
      readyItems={[
        "Protected internal access is in place through Supabase Auth.",
        "Dashboard has sales funnel and pipeline KPI placeholders ready for live data.",
        "The UI system is consistent with Finance, so CRM can reuse the same tables and forms.",
      ]}
      nextItems={[
        "Create leads, lead_notes, pipeline_stages, and outreach_activity tables in Supabase.",
        "Build the sales Kanban view and lead detail drawer.",
        "Replace mock dashboard CRM numbers with live pipeline and conversion metrics.",
      ]}
    />
  );
}
