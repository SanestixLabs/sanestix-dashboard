-- Sanestix OS — Phase 3: per-employee payday
-- Adds a recurring "day of month" salary is paid on, so the Upcoming
-- Payments widget can include payroll alongside debts/subscriptions.
-- Run this in the Supabase SQL editor AFTER schema.sql and
-- schema-phase2-registers.sql. Safe to re-run (guarded with IF NOT EXISTS /
-- a DO block that checks column existence first).

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employees'
      and column_name = 'pay_day'
  ) then
    alter table public.employees
      add column pay_day smallint check (pay_day between 1 and 31);
  end if;
end $$;

comment on column public.employees.pay_day is
  'Day of month (1-31) this employee''s salary is paid. Null = no fixed '
  'schedule set yet, so they are excluded from Upcoming Payments. Months '
  'shorter than the chosen day (e.g. 31 in February) are clamped to the '
  'last day of that month by the application, not by the database.';
