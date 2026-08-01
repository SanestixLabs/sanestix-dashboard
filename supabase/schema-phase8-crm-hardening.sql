-- Sanestix OS — Phase 8: CRM hardening.
-- Safe to re-run.

-- Prevent duplicate contact emails (case-insensitive), null-safe.
create unique index if not exists idx_crm_contacts_email_unique
  on public.crm_contacts (lower(email))
  where email is not null;

-- Prevent exact duplicate company names (case-insensitive).
create unique index if not exists idx_crm_companies_name_unique
  on public.crm_companies (lower(name));

-- A lead should always have an owner for follow-up accountability.
-- Backfill first for any existing null rows, then enforce.
update public.crm_leads set owner_id = created_by where owner_id is null;
alter table public.crm_leads alter column owner_id set not null;
