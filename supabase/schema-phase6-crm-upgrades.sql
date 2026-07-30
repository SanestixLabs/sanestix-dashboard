-- Sanestix OS — Phase 6: CRM production upgrades.
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Safe to re-run: everything is ADD COLUMN IF NOT EXISTS.
--
-- Adds:
--   crm_leads.lost_reason — captured when a lead is marked "lost", so the
--   CRM pipeline page can show a real win/loss breakdown instead of just a
--   raw lost count.

alter table public.crm_leads add column if not exists lost_reason text;
