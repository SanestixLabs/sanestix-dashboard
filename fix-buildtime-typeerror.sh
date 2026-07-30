#!/usr/bin/env bash
# Follow-up fix for deploy-persistent-layout.sh: removes 3 dead files that
# were never wired into any route (module-foundation.tsx, finance-register-
# page.tsx, dashboard-shell.tsx) but still got type-checked by `next build`
# because they called the old Topbar with a `breadcrumb` prop that no
# longer exists. Safe to re-run.
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "ERROR: run this from the repo root (where package.json and src/app live)."
  exit 1
fi

echo "==> Removing unused dead-code files that broke the TypeScript build"
rm -f src/components/layout/dashboard-shell.tsx
rm -f src/components/modules/module-foundation.tsx
rm -f src/components/finance/finance-register-page.tsx
rmdir src/components/modules 2>/dev/null || true

echo "==> Sanity check: confirming nothing still imports them"
if grep -rq "dashboard-shell\|module-foundation\|finance-register-page" src --include="*.ts" --include="*.tsx"; then
  echo "WARNING: something still references one of the removed files — check output below:"
  grep -rn "dashboard-shell\|module-foundation\|finance-register-page" src --include="*.ts" --include="*.tsx"
  exit 1
fi
echo "Clean — nothing references the removed files."

echo ""
echo "Done. Rebuild:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
