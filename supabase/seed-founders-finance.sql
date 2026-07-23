-- Sanestix OS — Founder finance seed (run AFTER the 3 founder accounts exist)
--
-- schema.sql seeds finance_transactions/invoices immediately because those
-- tables don't depend on any specific user. founder_loans and
-- profit_distributions do depend on the 3 founders existing first, so this
-- is a separate script:
--
--   1. Run schema.sql (once).
--   2. Run scripts/setup-founders.mjs (once) to create the 3 auth users.
--   3. Run this file (once) in the Supabase SQL editor.
--
-- It matches founders by full_name via INSERT...SELECT, so it's safe to
-- re-run: it inserts nothing if the founder names below don't match, and
-- checks for existing rows before inserting anything at all.
--
-- Edit the three names below to match the --name values you used with
-- setup-founders.mjs before running this.

do $$
declare
  founder_names text[] := array['Saad Faisal', 'Abdul Wahab Siddiqi', 'Shiekh Mateen Waqar'];
begin
  -- 1. Founder investments and reimbursements from the current company record.
  insert into public.founder_loans (founder_id, occurred_on, description, direction, amount)
  select p.id, v.occurred_on, v.description, v.direction, v.amount
  from (values
    (founder_names[1], date '2026-04-29', 'Founder investment covering company expenses', 'loan_in', 99880::numeric),
    (founder_names[3], date '2026-06-01', 'Founder investment / Mateen account entry', 'loan_in', 1200::numeric),
    (founder_names[1], date '2026-05-21', 'Loan returned', 'repayment_out', 14000::numeric),
    (founder_names[1], date '2026-05-31', 'Loan returned - original date unknown in source record', 'repayment_out', 15000::numeric),
    (founder_names[1], date '2026-05-21', 'Mail expense reimbursement', 'repayment_out', 2500::numeric),
    (founder_names[1], date '2026-06-01', 'Facebook ads reimbursement', 'repayment_out', 1255::numeric),
    (founder_names[1], date '2026-06-01', 'Adjustment', 'repayment_out', 45::numeric),
    (founder_names[1], date '2026-06-20', 'Loan returned', 'repayment_out', 10000::numeric),
    (founder_names[3], date '2026-06-01', 'Paid to Shiekh Mateen', 'repayment_out', 1200::numeric)
  ) as v(founder_name, occurred_on, description, direction, amount)
  join public.profiles p on p.full_name = v.founder_name
  where not exists (select 1 from public.founder_loans limit 1);

  -- 2. Profit distribution history from the cash distribution register.
  insert into public.profit_distributions (
    period_month, gross_profit, capital_reserve, loan_repayment,
    distributable_profit, charity_pct, charity_amount, per_founder_amount, note
  )
  select * from (values
    (date '2026-05-01', 30000::numeric, 2500::numeric, 14000::numeric,
     13500::numeric, 8.89::numeric, 1200::numeric, 4100::numeric,
     '21 May distribution: PKR 12,300 profit, PKR 1,200 charity, PKR 14,000 Saad repayment, PKR 2,500 mail expense'),
    (date '2026-06-01', 2500::numeric, 0::numeric, 1300::numeric,
     1200::numeric, 0::numeric, 0::numeric, 0::numeric,
     '01 Jun distribution: remaining Facebook ads PKR 1,255, Mateen PKR 1,200, Saad adjustment PKR 45'),
    (date '2026-06-01', 25000::numeric, 14000::numeric, 1000::numeric,
     10000::numeric, 10::numeric, 1000::numeric, 3000::numeric,
     '02 Jun distribution: PKR 9,000 profit, PKR 1,000 charity, PKR 14,000 lawyer fee, PKR 1,000 loan repayment'),
    (date '2026-06-01', 25000::numeric, 0::numeric, 10000::numeric,
     15000::numeric, 10::numeric, 1500::numeric, 4500::numeric,
     '20 Jun distribution: PKR 13,500 profit, PKR 1,500 charity, PKR 10,000 loan repayment')
  ) as v(
    period_month, gross_profit, capital_reserve, loan_repayment,
    distributable_profit, charity_pct, charity_amount, per_founder_amount, note
  )
  where exists (select 1 from public.profiles where full_name = any(founder_names))
    and not exists (select 1 from public.profit_distributions limit 1);
end $$;
