#!/usr/bin/env bash
# Deploy / redeploy the Sanestix Executive Dashboard on the VPS.
# Safe to re-run — it only touches this project's own container.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in your"
  echo "Supabase URL + anon key first (see README.md 'Auth & Database')."
  exit 1
fi

echo "==> Pulling latest code (skip if you rsync'd instead)"
if [ -d .git ]; then
  git pull
fi

echo "==> Building image"
docker compose build --no-cache

echo "==> Starting/replacing container"
docker compose up -d

echo "==> Status"
docker compose ps

echo ""
echo "Done. Once dashboard.sanestix.com DNS has propagated, check:"
echo "  https://dashboard.sanestix.com"
echo ""
echo "Logs:   docker compose logs -f"
echo "Stop:   docker compose down"
