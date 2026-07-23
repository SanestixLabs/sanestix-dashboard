-- Sanestix OS — Phase 1 schema (Auth + Finance)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is IF NOT EXISTS / CREATE OR REPLACE.

-- ---------------------------------------------------------------------------
-- 1. Profiles — one row per auth.users row, created automatically on signup.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  role text not null default 'member' check (role in ('admin', 'member')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by authenticated users" on public.profiles;
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Auto-create a profile row whenever a new user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2. Finance — the first real module. Everything else (Projects, CRM) stays
--    on mock data in src/lib/data.ts until those modules are built.
-- ---------------------------------------------------------------------------
create table if not exists public.finance_transactions (
  id uuid primary key default gen_random_uuid(),
  occurred_on date not null,
  kind text not null check (kind in ('revenue', 'expense')),
  category text,
  amount numeric(12, 2) not null check (amount >= 0),
  note text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  amount numeric(12, 2) not null check (amount >= 0),
  status text not null default 'outstanding' check (status in ('outstanding', 'paid', 'overdue')),
  due_date date not null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.finance_transactions enable row level security;
alter table public.invoices enable row level security;

-- Internal team tool: any signed-in user can read all finance data.
-- Tighten later (e.g. restrict to role = 'admin') once you have real staff roles.
drop policy if exists "Authenticated users can read transactions" on public.finance_transactions;
create policy "Authenticated users can read transactions"
  on public.finance_transactions for select to authenticated using (true);

drop policy if exists "Authenticated users can write transactions" on public.finance_transactions;
create policy "Authenticated users can write transactions"
  on public.finance_transactions for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update transactions" on public.finance_transactions;
create policy "Authenticated users can update transactions"
  on public.finance_transactions for update to authenticated using (true);

drop policy if exists "Authenticated users can read invoices" on public.invoices;
create policy "Authenticated users can read invoices"
  on public.invoices for select to authenticated using (true);

drop policy if exists "Authenticated users can write invoices" on public.invoices;
create policy "Authenticated users can write invoices"
  on public.invoices for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update invoices" on public.invoices;
create policy "Authenticated users can update invoices"
  on public.invoices for update to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 3. Seed Sanestix's current company finance data.
--    Founder-linked reimbursements/profit split rows live in
--    seed-founders-finance.sql because they need real auth user IDs first.
-- ---------------------------------------------------------------------------
insert into public.finance_transactions (occurred_on, kind, category, amount, note)
select * from (values
  (date '2026-04-29', 'expense', 'Learning', 30000, 'Course - paid by Saad Faisal'),
  (date '2026-04-29', 'expense', 'Software', 2990, 'Hosting - paid by Saad Faisal'),
  (date '2026-04-29', 'expense', 'Software', 1200, 'CapCut Pro - paid by Saad Faisal'),
  (date '2026-04-29', 'expense', 'Software', 5000, 'Voxiquo - paid by Saad Faisal'),
  (date '2026-04-29', 'expense', 'Equipment', 5500, 'Microphone - paid by Saad Faisal'),
  (date '2026-05-21', 'revenue', 'Client Payment', 30000, 'Nash - client payment'),
  (date '2026-05-22', 'expense', 'Marketing', 19272, 'Webinar Marketing - paid by Saad Faisal'),
  (date '2026-05-23', 'expense', 'Equipment', 2600, 'Business Email - paid by Saad Faisal'),
  (date '2026-06-01', 'revenue', 'Commission', 2500, 'Nash Hosting Commission'),
  (date '2026-06-01', 'expense', 'Software', 100, 'SEMrush - paid by Saad Faisal'),
  (date '2026-06-02', 'revenue', 'Client Payment', 25000, 'Nash - client payment'),
  (date '2026-06-04', 'expense', 'Legal', 14000, 'Lawyer - paid by Saad Faisal'),
  (date '2026-06-04', 'expense', 'Legal', 20418, 'Company Pvt Ltd Registration - paid by Saad Faisal'),
  (date '2026-06-20', 'revenue', 'Client Payment', 25000, 'Nash - client payment')
) as v(occurred_on, kind, category, amount, note)
where not exists (select 1 from public.finance_transactions limit 1);

-- No invoices are seeded yet because the current company record has cash
-- received entries, not formal invoice rows.

-- ---------------------------------------------------------------------------
-- 4. Founder loans + profit distribution ("loan recovery" / "profit split")
--    founder_loans      — a running ledger of money each founder has put in
--                         as a loan (loan_in) and what's been paid back to
--                         them (repayment_out). Outstanding = loaned - repaid.
--    profit_distributions — one row per month the 3-way waterfall is run:
--                         gross profit → capital reserve → loan repayment →
--                         charity % → equal 3-way founder split.
-- ---------------------------------------------------------------------------
create table if not exists public.founder_loans (
  id uuid primary key default gen_random_uuid(),
  founder_id uuid not null references public.profiles (id) on delete cascade,
  occurred_on date not null,
  description text not null,
  direction text not null check (direction in ('loan_in', 'repayment_out')),
  amount numeric(12, 2) not null check (amount > 0),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.profit_distributions (
  id uuid primary key default gen_random_uuid(),
  period_month date not null,
  gross_profit numeric(12, 2) not null,
  capital_reserve numeric(12, 2) not null default 0,
  loan_repayment numeric(12, 2) not null default 0,
  distributable_profit numeric(12, 2) not null,
  charity_pct numeric(5, 2) not null default 10,
  charity_amount numeric(12, 2) not null,
  per_founder_amount numeric(12, 2) not null,
  note text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.founder_loans enable row level security;
alter table public.profit_distributions enable row level security;

-- Internal team tool: any signed-in user can read/write. Tighten later
-- (e.g. restrict writes to role = 'admin') once you have real staff roles.
drop policy if exists "Authenticated users can read founder_loans" on public.founder_loans;
create policy "Authenticated users can read founder_loans"
  on public.founder_loans for select to authenticated using (true);

drop policy if exists "Authenticated users can write founder_loans" on public.founder_loans;
create policy "Authenticated users can write founder_loans"
  on public.founder_loans for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update founder_loans" on public.founder_loans;
create policy "Authenticated users can update founder_loans"
  on public.founder_loans for update to authenticated using (true);

drop policy if exists "Authenticated users can read profit_distributions" on public.profit_distributions;
create policy "Authenticated users can read profit_distributions"
  on public.profit_distributions for select to authenticated using (true);

drop policy if exists "Authenticated users can write profit_distributions" on public.profit_distributions;
create policy "Authenticated users can write profit_distributions"
  on public.profit_distributions for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update profit_distributions" on public.profit_distributions;
create policy "Authenticated users can update profit_distributions"
  on public.profit_distributions for update to authenticated using (true);
