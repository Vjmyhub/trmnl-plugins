# Market Brief — Docker deployment (e.g. for a Raspberry Pi)

Runs the same logic as `.github/workflows/push-market-brief.yml`, but as a
long-running Docker container with its own cron schedule — no dependency on
GitHub Actions at all. This also sidesteps GitHub's "scheduled workflows
auto-disable after 60 days of repo inactivity" behavior, since this runs
entirely on your own hardware.

## Why you'd use this instead of GitHub Actions

- Keeps running even if this repo goes quiet for months
- No GitHub account/billing dependency for the automation itself
- Cron runs in the container's local timezone (`America/New_York`, with
  real Daylight Saving handling), instead of GitHub Actions' fixed-UTC cron
  that drifts by an hour twice a year

## Files

- `push-market-brief.sh` — standalone version of the workflow's bash/Python logic (no GitHub-specific bits)
- `Dockerfile` — Alpine-based image with bash, curl, jq, python3, and cron
- `crontab` — runs the script 3x/weekday: 9:45am, 12:30pm, 4:30pm ET
- `entrypoint.sh` — works around a Docker+cron gotcha (see below)
- `docker-compose.yml` — the easiest way to build and run it
- `deploy.sh` — one-shot script that checks prerequisites, sets up `.env` interactively, builds, starts, and offers an immediate test run
- `.env.example` — copy to `.env` and fill in your real webhook URL (or let `deploy.sh` create it for you)

## Deploy on your Pi

These commands run **on the Pi itself** (over SSH) — I can't reach a
private/local IP like `10.x.x.x` from this session, so this part is on you.

### Easiest: `deploy.sh`

```bash
# 1. Get these files onto the Pi, e.g.:
scp -r market-brief/docker/ pi@10.242.1.43:~/market-brief-docker

# 2. SSH in and run the deploy script
ssh pi@10.242.1.43
cd ~/market-brief-docker
./deploy.sh
```

It will: check Docker is installed and running, prompt you for your TRMNL
webhook URL if `.env` doesn't exist yet, build and start the container,
show its status, and offer to run the script once immediately so you don't
have to wait for the next scheduled time to see if it worked.

### Manual equivalent, if you'd rather run each step yourself

```bash
cp .env.example .env
nano .env   # paste your real MARKET_BRIEF_WEBHOOK_URL
docker compose up -d --build
docker compose ps
docker compose logs -f
```

The container stays running (via `crond -f`) and fires the script on
schedule; `restart: unless-stopped` means it survives a Pi reboot.

### Test it immediately instead of waiting for the next scheduled time

```bash
docker compose exec market-brief sh -c '. /app/env.sh; /app/push-market-brief.sh'
```

### Updating after a template/script change

```bash
# back on the Pi, after re-copying the updated files:
./deploy.sh
# (or: docker compose up -d --build)
```

## The Docker+cron environment-variable gotcha

Docker environment variables (from `-e` or `environment:` in compose) are
only set for PID 1 in the container. Busybox's `crond` runs each job in a
near-empty environment, so a cron job can't see `MARKET_BRIEF_WEBHOOK_URL`
just because it was passed to `docker run`. `entrypoint.sh` works around
this by dumping that one variable to `/app/env.sh` at container startup,
which the crontab sources (`. /app/env.sh;`) before running the script each
time. If you add more env vars the script needs, add them to the `grep -E`
pattern in `entrypoint.sh` too.

## Verified vs. not yet verified

I ran the standalone script directly (bash/curl/jq already available in my
environment) and confirmed its control flow and fallback behavior are
correct, reviewed the Dockerfile/crontab/entrypoint for correctness, and
ran `deploy.sh` itself end-to-end — its prerequisite checks, `.env`
handling, and error propagation all behave correctly. I could **not**
fully build and run the container itself — my environment's network
policy blocks Alpine's package CDN, so `apk add` fails here specifically
(confirmed via a real `docker build`, not a guess). Your Pi will have
normal internet access and should get past this fine, but that means your
run of `./deploy.sh` is the real first full test — it'll offer to run the
script once immediately so you can confirm the device updates right away
instead of waiting for the next scheduled time.

## Running both GitHub Actions and this Docker setup at once?

Both would POST to the same TRMNL webhook independently. That's harmless —
TRMNL just takes whatever the most recent POST was — but means two systems
making near-duplicate requests on overlapping schedules. If you move to
this Docker setup, consider disabling the GitHub Actions workflow (Actions
tab → the workflow → "..." → Disable workflow) to avoid the redundancy.
