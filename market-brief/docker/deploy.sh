#!/usr/bin/env bash
# One-shot deployment script for the Market Brief Docker container.
# Run this ON THE TARGET MACHINE (e.g. your Raspberry Pi), from inside
# this market-brief/docker/ directory, after copying/cloning it there.

set -euo pipefail
cd "$(dirname "$0")"

echo "=== Market Brief Docker deployment ==="
echo

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed." >&2
  echo "Install it first: curl -fsSL https://get.docker.com | sh" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose (or docker-compose) is not available." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: can't talk to the Docker daemon. Is it running? Do you need sudo," >&2
  echo "or to add your user to the 'docker' group (then log out/in)?" >&2
  exit 1
fi

echo "Using: $COMPOSE"

# ---------------------------------------------------------------------------
# 2. Set up .env if missing
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
  echo
  echo "No .env found."
  if [ -t 0 ]; then
    read -rp "Enter your TRMNL webhook URL (https://trmnl.com/api/custom_plugins/...): " WEBHOOK_URL
    if [ -z "$WEBHOOK_URL" ]; then
      echo "ERROR: no webhook URL entered. Aborting." >&2
      exit 1
    fi
    echo "MARKET_BRIEF_WEBHOOK_URL=$WEBHOOK_URL" > .env
    echo "Wrote .env"
  else
    echo "ERROR: .env is missing and this isn't an interactive terminal." >&2
    echo "Create .env manually (see .env.example) and re-run this script." >&2
    exit 1
  fi
else
  echo ".env already exists — using it."
fi

# ---------------------------------------------------------------------------
# 3. Build and start
# ---------------------------------------------------------------------------
echo
echo "Building and starting the container..."
$COMPOSE up -d --build

echo
echo "Container status:"
$COMPOSE ps

# ---------------------------------------------------------------------------
# 4. Offer an immediate test run (don't wait for the next cron time)
# ---------------------------------------------------------------------------
echo
RUN_NOW="Y"
if [ -t 0 ]; then
  read -rp "Run the script once right now to test it end-to-end? [Y/n] " RUN_NOW
  RUN_NOW=${RUN_NOW:-Y}
fi

if [[ "$RUN_NOW" =~ ^[Yy] ]]; then
  echo "Running push-market-brief.sh inside the container..."
  if $COMPOSE exec market-brief sh -c '. /app/env.sh; /app/push-market-brief.sh'; then
    echo
    echo "Test run succeeded — check your TRMNL device now."
  else
    echo
    echo "WARNING: test run failed. Check the webhook URL in .env and your network," >&2
    echo "then re-run manually with:" >&2
    echo "  $COMPOSE exec market-brief sh -c '. /app/env.sh; /app/push-market-brief.sh'" >&2
  fi
fi

echo
echo "=== Deployment complete ==="
echo "Scheduled runs: 9:45am, 12:30pm, 4:30pm America/New_York, Mon-Fri."
echo
echo "Useful commands:"
echo "  $COMPOSE logs -f                                                          # follow logs"
echo "  $COMPOSE exec market-brief sh -c '. /app/env.sh; /app/push-market-brief.sh'  # run once manually"
echo "  $COMPOSE restart                                                          # restart the container"
echo "  $COMPOSE down                                                             # stop and remove it"
