-- Sanestix OS — Phase 4: full CRUD (delete) on every register + payroll
-- payment history with photo proof-of-payment.
-- Run this in the Supabase SQL editor AFTER schema.sql, schema-phase2 and
-- schema-phase3. Safe to re-run.

-- ---------------------------------------------------------------------------
-- 1. Delete policies — vendors, subscriptions, assets, debts, employees,
--    invoices previously only supported insert/update. This unlocks the
--    "Delete" button added to each register page.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['vendors', 'subscriptions', 'assets', 'debts', 'employees']
  loop
    execute format(
      'drop policy if exists "Authenticated users can delete %1$s" on public.%1$s;
       create policy "Authenticated users can delete %1$s" on public.%1$s
         for delete to authenticated using (true);', t
    );
  end loop;
end $$;

drop policy if exists "Authenticated users can delete invoices" on public.invoices;
create policy "Authenticated users can delete invoices"
  on public.invoices for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 2. employee_payments — one row per payday marked "paid", with an optional
--    photo of the transfer/receipt as proof.
-- ---------------------------------------------------------------------------
create table if not exists public.employee_payments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  amount numeric(12, 2) not null check (amount >= 0),
  pay_period date not null, -- first day of the month this payment covers
  paid_on date not null default current_date,
  proof_url text,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.employee_payments enable row level security;

drop policy if exists "Authenticated users can read employee_payments" on public.employee_payments;
create policy "Authenticated users can read employee_payments"
  on public.employee_payments for select to authenticated using (true);

drop policy if exists "Authenticated users can write employee_payments" on public.employee_payments;
create policy "Authenticated users can write employee_payments"
  on public.employee_payments for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update employee_payments" on public.employee_payments;
create policy "Authenticated users can update employee_payments"
  on public.employee_payments for update to authenticated using (true);

drop policy if exists "Authenticated users can delete employee_payments" on public.employee_payments;
create policy "Authenticated users can delete employee_payments"
  on public.employee_payments for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 3. Storage bucket for payment proof photos. Public read (the app is
--    already gated behind the finance password), authenticated-only write.
--    Object paths are namespaced by employee id + a random suffix, so a
--    stranger with the URL would have to already know/guess it.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', true)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload payment proofs" on storage.objects;
create policy "Authenticated users can upload payment proofs"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-proofs');

drop policy if exists "Anyone can view payment proofs" on storage.objects;
create policy "Anyone can view payment proofs"
  on storage.objects for select to public
  using (bucket_id = 'payment-proofs');

drop policy if exists "Authenticated users can delete payment proofs" on storage.objects;
create policy "Authenticated users can delete payment proofs"
  on storage.objects for delete to authenticated
  using (bucket_id = 'payment-proofs');
