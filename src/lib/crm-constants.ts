import type { LeadStage } from "@/lib/types";

// Single source of truth for stage → pill tone. Previously duplicated in
// crm/page.tsx and crm/leads/[id]/page.tsx.
export const STAGE_TONE: Record<LeadStage, "primary" | "neutral" | "success" | "warning" | "error"> = {
  new: "primary",
  contacted: "neutral",
  qualified: "neutral",
  proposal: "warning",
  won: "success",
  lost: "error",
};

export const ACTIVITY_LABEL: Record<string, string> = {
  note: "Note",
  call: "Call",
  email: "Email",
  meeting: "Meeting",
  stage_change: "Stage change",
};
