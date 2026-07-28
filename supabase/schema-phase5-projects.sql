-- Sanestix OS — Phase 5 schema: Projects module
-- Run this once in the Supabase SQL editor, AFTER schema.sql and
-- schema-phase2-registers.sql. Safe to re-run: everything is
-- IF NOT EXISTS / CREATE OR REPLACE.
--
-- Tables:
--   projects        — one row per client project
--   project_members — who's on a project (many-to-many: profiles <-> projects)
--   tasks           — Kanban tasks, always scoped to a project
--   task_assignees  — who's assigned to a task (many-to-many: profiles <-> tasks)
--   task_comments   — discussion thread on a task
--
-- Also (re-)creates activity_log and notifications if they don't already
-- exist, since this repo's earlier phases assumed those tables were added
-- ad hoc — see src/lib/audit.ts. Safe no-ops if they're already there.

-- ---------------------------------------------------------------------------
-- 0. activity_log + notifications (idempotent safety net — see src/lib/audit.ts)
-- ---------------------------------------------------------------------------
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  actor_email text,
  action text not null,
  entity text not null,
  entity_id uuid,
  summary text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id),
  type text not null,
  title text not null,
  body text,
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.activity_log enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Authenticated users can read activity_log" on public.activity_log;
create policy "Authenticated users can read activity_log"
  on public.activity_log for select to authenticated using (true);

drop policy if exists "Authenticated users can write activity_log" on public.activity_log;
create policy "Authenticated users can write activity_log"
  on public.activity_log for insert to authenticated with check (true);

drop policy if exists "Authenticated users can read notifications" on public.notifications;
create policy "Authenticated users can read notifications"
  on public.notifications for select to authenticated using (true);

drop policy if exists "Authenticated users can write notifications" on public.notifications;
create policy "Authenticated users can write notifications"
  on public.notifications for insert to authenticated with check (true);

-- ---------------------------------------------------------------------------
-- 1. Projects
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_name text,
  description text,
  status text not null default 'on_track'
    check (status in ('on_track', 'at_risk', 'delayed', 'completed')),
  owner_id uuid references public.profiles (id),
  start_date date,
  end_date date,
  budget numeric(12, 2),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'contributor',
  added_at timestamptz not null default now(),
  unique (project_id, member_id)
);

-- ---------------------------------------------------------------------------
-- 2. Tasks (Kanban)
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'backlog'
    check (status in ('backlog', 'todo', 'in_progress', 'review', 'done')),
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high', 'urgent')),
  due_date date,
  position bigint not null default 0,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_assignees (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  unique (task_id, member_id)
);

create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  author_id uuid references public.profiles (id),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists tasks_project_id_idx on public.tasks (project_id);
create index if not exists tasks_status_idx on public.tasks (status);
create index if not exists task_comments_task_id_idx on public.task_comments (task_id);

-- ---------------------------------------------------------------------------
-- 3. RLS — internal team tool: any signed-in user can read/write everything.
--    Tighten later (e.g. restrict deletes to owner/admin) once you have
--    real staff roles.
-- ---------------------------------------------------------------------------
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.task_comments enable row level security;

drop policy if exists "Authenticated users can read projects" on public.projects;
create policy "Authenticated users can read projects"
  on public.projects for select to authenticated using (true);
drop policy if exists "Authenticated users can write projects" on public.projects;
create policy "Authenticated users can write projects"
  on public.projects for insert to authenticated with check (true);
drop policy if exists "Authenticated users can update projects" on public.projects;
create policy "Authenticated users can update projects"
  on public.projects for update to authenticated using (true);
drop policy if exists "Authenticated users can delete projects" on public.projects;
create policy "Authenticated users can delete projects"
  on public.projects for delete to authenticated using (true);

drop policy if exists "Authenticated users can read project_members" on public.project_members;
create policy "Authenticated users can read project_members"
  on public.project_members for select to authenticated using (true);
drop policy if exists "Authenticated users can write project_members" on public.project_members;
create policy "Authenticated users can write project_members"
  on public.project_members for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete project_members" on public.project_members;
create policy "Authenticated users can delete project_members"
  on public.project_members for delete to authenticated using (true);

drop policy if exists "Authenticated users can read tasks" on public.tasks;
create policy "Authenticated users can read tasks"
  on public.tasks for select to authenticated using (true);
drop policy if exists "Authenticated users can write tasks" on public.tasks;
create policy "Authenticated users can write tasks"
  on public.tasks for insert to authenticated with check (true);
drop policy if exists "Authenticated users can update tasks" on public.tasks;
create policy "Authenticated users can update tasks"
  on public.tasks for update to authenticated using (true);
drop policy if exists "Authenticated users can delete tasks" on public.tasks;
create policy "Authenticated users can delete tasks"
  on public.tasks for delete to authenticated using (true);

drop policy if exists "Authenticated users can read task_assignees" on public.task_assignees;
create policy "Authenticated users can read task_assignees"
  on public.task_assignees for select to authenticated using (true);
drop policy if exists "Authenticated users can write task_assignees" on public.task_assignees;
create policy "Authenticated users can write task_assignees"
  on public.task_assignees for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete task_assignees" on public.task_assignees;
create policy "Authenticated users can delete task_assignees"
  on public.task_assignees for delete to authenticated using (true);

drop policy if exists "Authenticated users can read task_comments" on public.task_comments;
create policy "Authenticated users can read task_comments"
  on public.task_comments for select to authenticated using (true);
drop policy if exists "Authenticated users can write task_comments" on public.task_comments;
create policy "Authenticated users can write task_comments"
  on public.task_comments for insert to authenticated with check (true);
drop policy if exists "Authenticated users can delete task_comments" on public.task_comments;
create policy "Authenticated users can delete task_comments"
  on public.task_comments for delete to authenticated using (true);
