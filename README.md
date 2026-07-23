# Sanestix OS — Executive Dashboard

This is the first real screen of Sanestix OS, built from the locked Phase 0
design system (Stitch export: monochrome "Linear Minimalism" + cyan accent)
and the Phase 1.5 spec in `Sanestix-OS-Roadmap.md`:

> KPI cards pulling from Finance + Projects + CRM. 3–4 charts max at launch
> (Revenue Trend, Cash Flow, Sales Funnel, Project Progress).

It's a real, deployable Next.js app — not a static mockup. Data is mocked
today in a shape that mirrors what the FastAPI backend should return once
Phase 1.2–1.4 (Finance, Projects, CRM) ship, so wiring it up later is a
one-file change (see `src/lib/data.ts`).

## Stack

- **Next.js 16** (App Router, React Server Components)
- **TypeScript**
- **Tailwind CSS v4** — design tokens defined in `src/app/globals.css` as CSS
  variables (`@theme`), matching the DESIGN.md palette exactly
- **Recharts** — Revenue Trend and Cash Flow charts
- **lucide-react** — icon set

**Status:**
- **Auth** — real, via Supabase Auth (email/password). See "Auth & Database (Supabase)" below.
- **Finance** — real, backed by Supabase Postgres tables (`finance_transactions`, `invoices`).
- **Projects, CRM** — still mock data in `src/lib/data.ts`, clearly labeled, per the
  roadmap's own sequencing (Auth → Finance → Projects → CRM → Dashboard).

## Project structure

```
src/
  middleware.ts           Refreshes Supabase session, gates /login vs dashboard
  app/
    layout.tsx           Root layout, loads Inter + JetBrains Mono
    globals.css          Design tokens (colors, radius, fonts) as CSS vars
    page.tsx             The Executive Dashboard page (protected)
    login/page.tsx       Sign-in form
    signup/page.tsx      Sign-up form
    auth/actions.ts       Server actions: signIn / signUp / signOut
    finance/
      page.tsx            Overview — KPIs + revenue/cash-flow charts
      transactions/page.tsx Full transaction ledger + add-entry form
      invoices/page.tsx   Full invoice list + add-invoice form + inline status
      loans/page.tsx      Founder loan ledger + balances
      profit-split/page.tsx Profit distribution waterfall + history
      actions.ts          Server actions: addTransaction, addInvoice,
                          updateInvoiceStatus, addLoanEntry, addProfitDistribution
  components/
    layout/
      sidebar.tsx         Module switcher (Dashboard/Finance/Projects/CRM/...)
      topbar.tsx          Breadcrumb, global search, notifications
      dashboard-shell.tsx Combines sidebar + topbar + content canvas
      finance-tabs.tsx    Overview/Transactions/Invoices/Loans/Profit Split tabs
    dashboard/
      kpi-card.tsx
      revenue-trend-chart.tsx
      cash-flow-chart.tsx
      sales-funnel-chart.tsx
      project-progress-chart.tsx
      activity-feed.tsx
    finance/
      invoice-status-form.tsx Inline invoice-status dropdown (client component)
    ui/
      card.tsx
      status-pill.tsx
  lib/
    types.ts              Shared domain types (mirrors future API shapes)
    data.ts                getDashboardData() — merges real Finance data
                           with mock Projects/CRM data
    utils.ts               cn(), formatCurrency() (PKR), formatNumber()
    supabase/
      client.ts             Browser Supabase client (client components)
      server.ts              Server Supabase client (Server Components/Actions)
      queries.ts              getFinanceData(), getTransactions(), getInvoices(),
                               getFounders(), getLoanLedger(), getLoanBalances(),
                               getProfitDistributions()
scripts/
  setup-founders.mjs      Run locally: provisions the 3 founder auth accounts
                          via the Supabase Admin API (needs service_role key)
supabase/
  schema.sql              Run this once in the Supabase SQL editor
  seed-founders-finance.sql Run once, after the 3 founders exist, to seed
                          their loan ledger + profit-split history
```

## Auth & Database (Supabase)

This app uses [Supabase](https://supabase.com) for both auth and the database
— a hosted Postgres with built-in auth, so there's nothing to self-host.

### 1. Create the project

1. Go to https://supabase.com/dashboard → **New project**.
2. Pick a name (e.g. `sanestix-os`), a strong database password (save it
   somewhere — Supabase won't show it again), and a region close to your
   VPS (e.g. Frankfurt/Singapore depending on where `72.61.143.58` is).
3. Wait ~2 minutes for provisioning.

### 2. Run the schema

1. In the project, open **SQL Editor → New query**.
2. Paste the entire contents of `supabase/schema.sql` (in this repo) and
   run it. This creates:
   - `profiles` — one row per user, auto-created on signup, with a `role`
     column (`admin`/`member`) for later use
   - `finance_transactions` and `invoices` — the real tables behind the
     Finance Overview/Transactions/Invoices pages, with Row Level Security
     enabled and several months of realistic **PKR** seed data across
     multiple categories (payroll, rent, marketing, software, taxes, etc.)
     so the dashboard isn't empty on first login
   - `founder_loans` and `profit_distributions` — the tables behind the
     Loan Ledger and Profit Split pages (left empty here — see step 6 below)
3. You can re-run this file safely later — it's idempotent.

### 3. Get your API keys

**Project Settings → API** (gear icon, bottom left). You need:

- **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
- **anon / public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Both are safe to expose to the browser — Row Level Security in
`schema.sql` is what actually controls access, not secrecy of these keys.

### 4. Turn off email confirmation for now (optional, faster local testing)

**Authentication → Providers → Email** → toggle off "Confirm email" if you
want to sign up and immediately sign in without clicking a confirmation
email. Turn it back on before giving real people accounts.

### 5. Set your env vars

```bash
cp .env.example .env
# then edit .env and paste in the two values from step 3
```

### 6. Create the 3 founder accounts (optional)

The Loan Ledger and Profit Split pages need real founder accounts to attach
loans/distributions to. This app doesn't have an admin UI for that yet, so
it's done with a script that talks directly to the Supabase Admin API —
run it locally, not from the deployed app:

```bash
# also grab the service_role key from Project Settings → API and put it in
# .env as SUPABASE_SERVICE_ROLE_KEY (never commit this — it bypasses RLS)
export $(grep -v '^#' .env | xargs)
npm run setup:founders -- \
  --name "Founder One"   --email founder1@sanestix.com \
  --name "Founder Two"   --email founder2@sanestix.com \
  --name "Founder Three" --email founder3@sanestix.com
```

This creates 3 pre-confirmed auth users (no email confirmation needed),
generates a strong random password for each, and prints a credentials table
— **save those passwords immediately**, they're shown once and never stored.
The `handle_new_user` trigger from `schema.sql` fills in `profiles`
automatically for each.

Then, in the SQL Editor, run `supabase/seed-founders-finance.sql` (after
editing the `founder_names` array at the top to match the `--name` values
you used above) to seed a few months of loan-ledger and profit-split history
for these three founders.

## Run locally

```bash
npm install
cp .env.example .env   # fill in your Supabase URL + anon key
npm run dev
```

Open http://localhost:3000 — you'll be redirected to `/login`. Use
`/signup` to create your first account.

## Build for production

```bash
npm run build
npm run start
```

## Deploy — this VPS (sanestix, Traefik)

This server already runs **Traefik** as the single reverse proxy on ports
80/443 (used by `n8n`, `sanestix-flow`, and `marwaa-whatsapp`). The host's
system `nginx` is not actually in the request path for those projects and
is currently crash-looping because Traefik holds port 80 — that's a
pre-existing issue, unrelated to this deploy, and this setup doesn't touch
nginx at all.

This project follows the same pattern: **its own container, on the shared
`n8n_default` Docker network, exposed only via Traefik labels.** No host
ports are published, no other project's files or containers are touched.

**One-time DNS step (do this first, outside the VPS):** in your DNS
provider for `sanestix.com`, add:

```
Type: A
Name: dashboard
Value: 72.61.143.58
```

**On the VPS:**

```bash
# 1. Get the code onto the box, e.g.:
mkdir -p /opt/sanestix-dashboard
# copy the contents of this folder into /opt/sanestix-dashboard
# (scp, rsync, or git clone your repo there)

cd /opt/sanestix-dashboard

# 2. Create .env with your real Supabase values (this file is gitignored —
#    create it directly on the VPS, don't commit it)
cp .env.example .env
nano .env   # paste in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY

# 3. Build and start
docker compose build
docker compose up -d

# or just:
./deploy.sh
```

**Important:** the Supabase URL/key are baked into the JS bundle at
`docker compose build` time (see the Dockerfile's `ARG`s). If you ever
change `.env`, you must rebuild (`docker compose build`), not just
restart — `deploy.sh` already does this for you.

Traefik picks the new container up automatically via its Docker labels
(`docker.providers=true`) — no Traefik restart needed. It will request a
Let's Encrypt cert for `dashboard.sanestix.com` via the existing
`mytlschallenge` HTTP-challenge resolver the first time it sees traffic on
that host, using the same flow as `flow.sanestix.com`.

**Check it worked:**

```bash
docker compose ps                 # container should be "Up"
docker compose logs -f            # app logs
docker logs n8n-traefik-1 --tail 50   # confirm Traefik picked up the router
```

Then visit `https://dashboard.sanestix.com`.

**Redeploying after a code change:** re-run `./deploy.sh`, or
`docker compose up -d --build`.

**Removing it entirely:** `docker compose down` in `/opt/sanestix-dashboard`
— this only stops/removes this project's own container; nothing shared is
affected.

## Deploy — elsewhere (Vercel, other hosts)

**Vercel (zero config):** push to a GitHub repo, import at
https://vercel.com/new — Next.js is auto-detected.

**Any other Docker host:** the `Dockerfile` here is self-contained
(multi-stage, Next.js standalone output). Build and run it directly:

```bash
docker build -t sanestix-dashboard .
docker run -p 3000:3000 sanestix-dashboard
```

## Wiring in the next module (Projects or CRM)

Finance is the template. To bring Projects or CRM onto real data:

1. Design the table(s) in Supabase (SQL editor), following the pattern in
   `supabase/schema.sql` — RLS enabled, `authenticated`-role policies.
2. Add a `getProjectsData()` / `getCrmData()` function to
   `src/lib/supabase/queries.ts`, shaped to return the relevant slice of
   `DashboardData` (see `getFinanceData()` for the pattern).
3. Merge it into `getDashboardData()` in `src/lib/data.ts` the same way
   Finance is merged — replace the corresponding mock KPIs/chart data,
   keep everything else.

No component changes are required — every chart and card already reads
from the `DashboardData` shape in `src/lib/types.ts`.

## Design system notes

Colors, spacing, radius, and type scale live as CSS variables in
`src/app/globals.css` under `:root` and are exposed to Tailwind via
`@theme inline`, so utility classes like `bg-surface`, `text-on-surface-variant`,
`border-outline-variant`, and `text-primary` are available everywhere.
Corners are 2px ("sharp") across cards, buttons, and inputs, matching the
Stitch DESIGN.md spec. Fonts (Inter for UI, JetBrains Mono for
labels/data/timestamps) are loaded via a `<link>` tag rather than
`next/font`, so the build has no external dependency at build time — only
the browser needs network access to Google Fonts at runtime.

## What's deliberately not here yet

Per the roadmap's own risk list ("Dashboard-first is a trap"), this ships
with realistic mock data, not a live dashboard wired to nothing. The
roadmap's actual build order is Auth → Finance → Projects → CRM →
Dashboard — this screen is the target the other four modules build
toward, built first because Phase 0 says UI should be locked before app
code exists.
