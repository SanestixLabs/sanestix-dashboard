import type { SupabaseClient } from "@supabase/supabase-js";

type RecordActivityParams = {
  supabase: SupabaseClient;
  actorId: string | null;
  actorEmail: string | null;
  action: string;
  entity: string;
  entityId: string | null;
  summary: string;
  notify?: boolean;
  notifyLink?: string;
};

/**
 * Logs an activity row for auditing, and optionally creates a broadcast
 * in-app notification (shown in the topbar) when notify is true.
 *
 * Notifications are written to the existing `notifications` table with
 * user_id left null (broadcast to everyone) since there's currently no
 * teams/roles table to fan out to individual users. Revisit this once
 * a profiles/team table exists.
 *
 * This never throws — logging/notification failures are reported to the
 * console but should not block the calling action from completing.
 */
export async function recordActivity({
  supabase,
  actorId,
  actorEmail,
  action,
  entity,
  entityId,
  summary,
  notify = false,
  notifyLink,
}: RecordActivityParams) {
  const { error: logError } = await supabase.from("activity_log").insert({
    actor_id: actorId,
    actor_email: actorEmail,
    action,
    entity,
    entity_id: entityId,
    summary,
  });

  if (logError) {
    console.error("Failed to record activity log:", logError.message);
  }

  if (notify) {
    const { error: notifyError } = await supabase.from("notifications").insert({
      user_id: null, // broadcast — visible to everyone until per-user targeting exists
      type: `${entity}.${action}`,
      title: summary,
      body: null,
      link: notifyLink ?? null,
    });

    if (notifyError) {
      console.error("Failed to create notification:", notifyError.message);
    }
  }
}
