import { getProjects, getCrmLeads, getCrmCompanies } from "@/lib/supabase/queries";

export const dynamic = "force-dynamic";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function csvRow(values: Array<string | number | null | undefined>) {
  return values.map(csvCell).join(",");
}

export async function GET() {
  try {
    const [projects, leads, companies] = await Promise.all([
      getProjects(),
      getCrmLeads(),
      getCrmCompanies(),
    ]);

    const rows = [
      csvRow(["Section", "Date", "Status/Stage", "Name", "Client/Company", "Detail", "Value PKR"]),
      ...projects.map((project) =>
        csvRow([
          "Projects",
          project.createdAt,
          project.status,
          project.name,
          project.clientName,
          `${project.doneTaskCount}/${project.taskCount} tasks done, ${project.overdueTaskCount} overdue`,
          project.budget ?? "",
        ])
      ),
      ...leads.map((lead) =>
        csvRow([
          "CRM Leads",
          lead.createdAt,
          lead.stage,
          lead.title,
          lead.companyName,
          lead.ownerName ? `Owner: ${lead.ownerName}` : "",
          lead.value,
        ])
      ),
      ...companies.map((company) =>
        csvRow([
          "CRM Companies",
          company.createdAt,
          "",
          company.name,
          company.industry,
          `${company.contactCount} contacts, ${company.leadCount} leads`,
          "",
        ])
      ),
    ];

    return new Response(rows.join("\n"), {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="sanestix-reports-export.csv"',
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown export error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
