import { Card, CardDescription, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/server";

type ActivityLogRow = {
  id: string;
  actor_email: string | null;
  action: string;
  entity: string;
  entity_id: string | null;
  summary: string;
  created_at: string;
};

function formatWhen(iso: string) {
  const d = new Date(iso);
  return d.toLocaleString("en-PK", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function actionTone(action: string) {
  if (action === "insert") return "text-success";
  if (action === "delete") return "text-error";
  return "text-on-surface-variant";
}

/**
 * Renders recent rows from `activity_log`.
 *
 * - `entity`: pass a single entity name (e.g. "finance_transactions") to
 *   scope the log to one page, or omit it to show everything (dashboard).
 * - `limit`: how many rows to show. Defaults to 15.
 */
export async function ActivityLog({
  entity,
  limit = 15,
  title = "Activity log",
  description = "Recent changes, newest first.",
}: {
  entity?: string | string[];
  limit?: number;
  title?: string;
  description?: string;
}) {
  const supabase = await createClient();

  let query = supabase
    .from("activity_log")
    .select("id, actor_email, action, entity, entity_id, summary, created_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (entity) {
    query = Array.isArray(entity) ? query.in("entity", entity) : query.eq("entity", entity);
  }

  const { data, error } = await query;
  const rows = (data ?? []) as ActivityLogRow[];

  return (
    <Card className="p-6">
      <CardTitle>{title}</CardTitle>
      <CardDescription>{description}</CardDescription>

      <div className="mt-4 max-h-[420px] overflow-auto">
        <table className="w-full text-left text-[13px]">
          <thead className="sticky top-0 bg-surface">
            <tr className="border-b border-outline-variant text-[10px] font-mono-data uppercase tracking-widest text-on-surface-variant/70">
              <th className="pb-2 pr-4">When</th>
              <th className="pb-2 pr-4">Action</th>
              <th className="pb-2 pr-4">Summary</th>
              <th className="pb-2 text-right">By</th>
            </tr>
          </thead>
          <tbody>
            {error && (
              <tr>
                <td colSpan={4} className="py-6 text-center text-error">
                  Couldn&apos;t load activity log.
                </td>
              </tr>
            )}
            {!error && rows.length === 0 && (
              <tr>
                <td colSpan={4} className="py-6 text-center text-on-surface-variant">
                  No activity yet.
                </td>
              </tr>
            )}
            {rows.map((row) => (
              <tr key={row.id} className="border-b border-outline-variant/50">
                <td className="py-2.5 pr-4 font-mono-data text-on-surface-variant whitespace-nowrap">
                  {formatWhen(row.created_at)}
                </td>
                <td className={"py-2.5 pr-4 font-mono-data uppercase text-[11px] " + actionTone(row.action)}>
                  {row.action}
                </td>
                <td className="py-2.5 pr-4 text-on-surface">{row.summary}</td>
                <td className="py-2.5 text-right text-on-surface-variant whitespace-nowrap">
                  {row.actor_email ?? "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
