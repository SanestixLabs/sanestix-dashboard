#!/usr/bin/env node
/**
 * Sanestix OS — Founder account setup
 *
 * Creates the 3 founder auth accounts directly via the Supabase Admin API,
 * bypassing signup/email-confirmation. Each account is created pre-confirmed
 * with full_name in user metadata, so the `handle_new_user` trigger in
 * schema.sql fills in `public.profiles` automatically.
 *
 * This must run OUTSIDE the app, on your own machine, because it needs the
 * SUPABASE_SERVICE_ROLE_KEY — a secret that must never reach the browser or
 * be committed to the repo.
 *
 * Usage:
 *   1. Run `schema.sql` in the Supabase SQL editor first.
 *   2. In your .env (or shell), set:
 *        NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
 *        SUPABASE_SERVICE_ROLE_KEY=eyJ...        (Project Settings → API → service_role)
 *   3. Run:
 *        node scripts/setup-founders.mjs \
 *          --name "Founder One" --email founder1@sanestix.com \
 *          --name "Founder Two" --email founder2@sanestix.com \
 *          --name "Founder Three" --email founder3@sanestix.com
 *      Or just: node scripts/setup-founders.mjs  (uses the defaults below —
 *      edit FOUNDERS first, or pass --name/--email pairs to override).
 *   4. Save the generated passwords printed at the end somewhere safe (a
 *      password manager) — they are shown only once and not stored anywhere.
 *   5. Run `supabase/seed-founders-finance.sql` afterwards, with the same
 *      names, to seed loan ledger + profit-split history for these founders.
 */

import { createClient } from "@supabase/supabase-js";
import crypto from "node:crypto";

// Edit these, or override via repeated --name/--email pairs on the CLI.
const DEFAULT_FOUNDERS = [
  { name: "Saad Faisal", email: "saad@sanestix.com" },
  { name: "Abdul Wahab Siddiqi", email: "wahab@sanestix.com" },
  { name: "Shiekh Mateen Waqar", email: "mateen@sanestix.com" },
];

function parseArgs(argv) {
  const names = [];
  const emails = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--name") names.push(argv[++i]);
    else if (argv[i] === "--email") emails.push(argv[++i]);
  }
  if (names.length === 0) return DEFAULT_FOUNDERS;
  if (names.length !== emails.length) {
    console.error("Error: every --name needs a matching --email (and vice versa).");
    process.exit(1);
  }
  return names.map((name, i) => ({ name, email: emails[i] }));
}

// 16-char password: mixed case, digits, symbols — generated locally, never
// sent anywhere except directly into the Supabase Admin API call below.
function generatePassword() {
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*";
  const bytes = crypto.randomBytes(20);
  let pw = "";
  for (let i = 0; i < 20; i++) pw += alphabet[bytes[i] % alphabet.length];
  return pw;
}

async function main() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.\n" +
        "Set both in your environment (or .env, then `export $(cat .env | xargs)`) before running this script."
    );
    process.exit(1);
  }

  const founders = parseArgs(process.argv.slice(2));

  const supabase = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const results = [];

  for (const founder of founders) {
    const password = generatePassword();

    const { data, error } = await supabase.auth.admin.createUser({
      email: founder.email,
      password,
      email_confirm: true, // pre-confirmed — no confirmation email needed
      user_metadata: { full_name: founder.name },
    });

    if (error) {
      console.error(`Failed to create ${founder.email}: ${error.message}`);
      results.push({ ...founder, password: null, status: `ERROR: ${error.message}` });
      continue;
    }

    results.push({ ...founder, password, status: "created", userId: data.user?.id });
  }

  console.log("\nFounder account setup — results\n");
  console.log(
    "Name".padEnd(18) + "Email".padEnd(28) + "Password".padEnd(22) + "Status"
  );
  console.log("-".repeat(90));
  for (const r of results) {
    console.log(
      r.name.padEnd(18) +
        r.email.padEnd(28) +
        (r.password ?? "—").padEnd(22) +
        r.status
    );
  }

  console.log(
    "\nSave the passwords above now — they are not stored anywhere and cannot be retrieved later.\n" +
      "Next: run supabase/seed-founders-finance.sql (edit the founder_names array to match the\n" +
      "names above) to seed loan ledger + profit-split history for these three accounts.\n"
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
