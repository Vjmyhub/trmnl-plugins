#!/bin/sh
# Docker env vars (passed via -e / docker-compose `environment:`) are only
# set for PID 1 — busybox cron jobs run in a near-empty environment and
# don't inherit them. Dump the vars this script needs to a file that the
# crontab sources before each run.
printenv | grep -E '^(MARKET_BRIEF_WEBHOOK_URL)=' | sed 's/^/export /' > /app/env.sh
chmod 600 /app/env.sh

exec crond -f -l 2
