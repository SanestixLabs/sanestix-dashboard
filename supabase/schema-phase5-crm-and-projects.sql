-- Sanestix OS — Phase 5 schema (CRM + minimal real Projects)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is IF NOT EXISTS / CREATE OR REPLACE.
--
-- Adds:
--   crm_companies        — organizations you sell to
--   crm_contacts         — people at those companies
--   crm_leads            — the pipeline itself (stage, value, owner)
--   crm_lead_activities  — notes/calls/emails/meetings/stage-change log per lead
--   crm_lead_tasks       — follow-up reminders per lead, with due dates
--   projects             — minimal real Projects table; a lead marked "won"
--                          auto-creates a draft row here (see app/crm/actions.ts)

-- ---------------------------------------------------------------------------
-- 1. Companies
-- ---------------------------------------------------------------------------
create table if not exists public.crm_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry text,
  website text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Contacts — a person, optionally tied to a company
-- ---------------------------------------------------------------------------
create table if not exists public.crm_contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.crm_companies (id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  title text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Leads — the pipeline. Stage list mirrors the dashboard's Sales Funnel
--    chart exactly (New → Contacted → Qualified → Proposal → Won/Lost) so
--    lib/supabase/queries.ts can build that chart straight from counts here.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company_id uuid references public.crm_companies (id) on delete set null,
  contact_id uuid references public.crm_contacts (id) on delete set null,
  stage text not null default 'new'
    check (stage in ('new', 'contacted', 'qualified', 'proposal', 'won', 'lost')),
  value numeric(12, 2) not null default 0 check (value >= 0),
  source text,
  owner_id uuid references public.profiles (id),
  expected_close_date date,
  notes text,
  converted_project_id uuid,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists crm_leads_set_updated_at on public.crm_leads;
create trigger crm_leads_set_updated_at
  before update on public.crm_leads
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. Lead activity log — notes, calls, emails, meetings, stage changes.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_lead_activities (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.crm_leads (id) on delete cascade,
  kind text not null default 'note'
    check (kind in ('note', 'call', 'email', 'meeting', 'stage_change')),
  content text not null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. Lead follow-up tasks — "call back Thursday" style reminders.
-- ---------------------------------------------------------------------------
create table if not exists public.crm_lead_tasks (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.crm_leads (id) on delete cascade,
  title text not null,
  due_date date not null,
  done boolean not null default false,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. Projects — minimal real table. A "won" lead auto-creates a draft row
--    here (source_lead_id links back), so CRM → Projects is a real handoff
--    instead of two disconnected modules. Projects module can grow later
--    (tasks, members, comments) without touching this table's shape.
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_name text,
  company_id uuid references public.crm_companies (id) on delete set null,
  status text not null default 'on_track'
    check (status in ('on_track', 'at_risk', 'delayed', 'completed')),
  source_lead_id uuid references public.crm_leads (id) on delete set null,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.crm_leads
  add constraint crm_leads_converted_project_id_fkey
  foreign key (converted_project_id) references public.projects (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 7. RLS — same internal-tool pattern as every other table in this app:
--    any signed-in user can read/write. Tighten later once real staff
--    roles exist.
-- ---------------------------------------------------------------------------
alter table public.crm_companies enable row level security;
alter table public.crm_contacts enable row level security;
alter table public.crm_leads enable row level security;
alter table public.crm_lead_activities enable row level security;
alter table public.crm_lead_tasks enable row level security;
alter table public.projects enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['crm_companies', 'crm_contacts', 'crm_leads', 'crm_lead_activities', 'crm_lead_tasks', 'projects']
  loop
    execute format('drop policy if exists "Authenticated users can read %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can read %1$s" on public.%1$s for select to authenticated using (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can write %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can write %1$s" on public.%1$s for insert to authenticated with check (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can update %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can update %1$s" on public.%1$s for update to authenticated using (true)',
      t
    );

    execute format('drop policy if exists "Authenticated users can delete %1$s" on public.%1$s', t);
    execute format(
      'create policy "Authenticated users can delete %1$s" on public.%1$s for delete to authenticated using (true)',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Helpful indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_crm_contacts_company_id on public.crm_contacts (company_id);
create index if not exists idx_crm_leads_company_id on public.crm_leads (company_id);
create index if not exists idx_crm_leads_contact_id on public.crm_leads (contact_id);
create index if not exists idx_crm_leads_stage on public.crm_leads (stage);
create index if not exists idx_crm_lead_activities_lead_id on public.crm_lead_activities (lead_id);
create index if not exists idx_crm_lead_tasks_lead_id on public.crm_lead_tasks (lead_id);
create index if not exists idx_crm_lead_tasks_due_date on public.crm_lead_tasks (due_date) where not done;
create index if not exists idx_projects_source_lead_id on public.projects (source_lead_id);
