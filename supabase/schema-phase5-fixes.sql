-- Sanestix OS — Phase 5: fixes for two gaps found in a finance-module audit.
alter table public.finance_transactions add column if not exists proof_url text;
alter table public.invoices             add column if not exists proof_url text;
alter table public.subscriptions        add column if not exists proof_url text;
alter table public.assets               add column if not exists proof_url text;
alter table public.debts                add column if not exists proof_url text;

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
alter table public.activity_log enable row level security;
drop policy if exists "Authenticated users can read activity_log" on public.activity_log;
create policy "Authenticated users can read activity_log" on public.activity_log for select to authenticated using (true);
drop policy if exists "Authenticated users can write activity_log" on public.activity_log;
create policy "Authenticated users can write activity_log" on public.activity_log for insert to authenticated with check (true);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id),
  type text not null,
  title text not null,
  body text,
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
drop policy if exists "Authenticated users can read notifications" on public.notifications;
create policy "Authenticated users can read notifications" on public.notifications for select to authenticated using (true);
drop policy if exists "Authenticated users can write notifications" on public.notifications;
create policy "Authenticated users can write notifications" on public.notifications for insert to authenticated with check (true);

create index if not exists activity_log_created_at_idx on public.activity_log (created_at desc);
create index if not exists activity_log_entity_idx on public.activity_log (entity);
create index if not exists notifications_created_at_idx on public.notifications (created_at desc);
