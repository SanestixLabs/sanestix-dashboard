-- Sanestix OS — Phase 7: Projects/Tasks upgrades (Jira/ClickUp-style).
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is ADD COLUMN IF NOT EXISTS / CREATE INDEX IF NOT EXISTS.
--
-- Adds:
--   tasks.labels — a small set of free-form tags per task (e.g. "Bug",
--   "Feature", "Client Request"), filterable on the Kanban board.

alter table public.tasks add column if not exists labels text[] not null default '{}'::text[];
create index if not exists tasks_labels_idx on public.tasks using gin (labels);
