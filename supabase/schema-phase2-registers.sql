-- Sanestix OS — Phase 2 Finance registers
-- Vendors, Subscriptions, Assets, Debts & Liabilities, Employees.
-- Run this once in the Supabase SQL editor, AFTER schema.sql.
-- Safe to re-run: everything is IF NOT EXISTS / CREATE OR REPLACE.

-- ---------------------------------------------------------------------------
-- 1. Vendors
-- ---------------------------------------------------------------------------
create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  contact_person text,
  contact_email text,
  payment_terms text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Subscriptions
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  vendor_name text not null,
  cost numeric(12, 2) not null check (cost >= 0),
  billing_cycle text not null default 'monthly' check (billing_cycle in ('monthly', 'annual')),
  renewal_date date,
  owner text,
  status text not null default 'active' check (status in ('active', 'cancelled')),
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Assets
-- ---------------------------------------------------------------------------
create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  purchase_date date not null,
  cost numeric(12, 2) not null check (cost >= 0),
  owner text,
  condition text not null default 'good' check (condition in ('new', 'good', 'fair', 'poor', 'disposed')),
  serial_number text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. Debts & Liabilities
-- ---------------------------------------------------------------------------
create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  counterparty text not null,
  principal numeric(12, 2) not null check (principal >= 0),
  paid_amount numeric(12, 2) not null default 0 check (paid_amount >= 0),
  due_date date,
  status text not null default 'outstanding' check (status in ('outstanding', 'paid', 'overdue')),
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. Employees
-- ---------------------------------------------------------------------------
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  role text,
  salary numeric(12, 2) check (salary >= 0),
  start_date date,
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  profile_id uuid references public.profiles (id),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS — same pattern as schema.sql: internal team tool, any signed-in user
-- can read/write. Tighten later (e.g. restrict to role = 'admin') once you
-- have real staff roles.
-- ---------------------------------------------------------------------------
alter table public.vendors enable row level security;
alter table public.subscriptions enable row level security;
alter table public.assets enable row level security;
alter table public.debts enable row level security;
alter table public.employees enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['vendors', 'subscriptions', 'assets', 'debts', 'employees']
  loop
    execute format(
      'drop policy if exists "Authenticated users can read %1$s" on public.%1$s;
       create policy "Authenticated users can read %1$s" on public.%1$s
         for select to authenticated using (true);', t
    );
    execute format(
      'drop policy if exists "Authenticated users can write %1$s" on public.%1$s;
       create policy "Authenticated users can write %1$s" on public.%1$s
         for insert to authenticated with check (true);', t
    );
    execute format(
      'drop policy if exists "Authenticated users can update %1$s" on public.%1$s;
       create policy "Authenticated users can update %1$s" on public.%1$s
         for update to authenticated using (true);', t
    );
  end loop;
end $$;
