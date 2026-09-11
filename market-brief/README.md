# Market Brief 📈 — TRMNL Plugin

Your daily briefing on one e-ink display: a short AI-written note, S&P 500 status, why the market moved, and JPMorgan (JPM) stock — updated automatically after each US market close.

## How it works

```
GitHub Action (scheduled) → fetches S&P 500 + JPM quotes → AI writes reason + brief → POSTs to TRMNL webhook → your e-ink display
```

No server needed — it runs entirely on GitHub Actions using free GitHub Models (no external API key required).

## Setup

### 1. Create a Private Plugin on TRMNL

1. Go to [trmnl.com](https://trmnl.com) → **Plugins** → **Add New** → **Private Plugin**
2. Strategy: **Webhook**
3. Name it "Market Brief 📈"
4. Copy the **Webhook URL** — you'll need it in step 3
5. Paste `template.liquid` into the **Markup** field
6. Set layout to `full`

### 2. Fork this repo

Fork it to your own GitHub account (keep it private if you prefer).

### 3. Add your webhook URL as a secret

1. Go to your fork → **Settings** → **Secrets and variables** → **Actions**
2. Add a new secret:
   - Name: `MARKET_BRIEF_WEBHOOK_URL`
   - Value: your webhook URL from step 1

> Uses a distinct secret name from the other plugins so you can run several private plugins from the same fork at once.

### 4. Enable the GitHub Action

The Action runs weekdays at 21:30 UTC (shortly after the 4:00pm ET US market close). You can also trigger it manually from the **Actions** tab.

## What it shows

- A short AI-written daily brief line
- S&P 500: price, % change, direction, and a one-sentence AI-generated reason for the move
- JPMorgan (JPM): price, % change, direction

## Customization

Edit `.github/workflows/push-market-brief.yml` to change:
- **Schedule**: modify the cron expression (`30 21 * * 1-5`)
- **Tickers**: change `%5EGSPC` (S&P 500) or `JPM` in the Yahoo Finance URLs to track other indices/stocks
- **AI model**: the "Generate brief + reason" step uses GitHub Models (`gpt-4o`) with your repo's built-in `GITHUB_TOKEN` — swap in the Claude/Anthropic API instead if you'd prefer (requires adding an `ANTHROPIC_API_KEY` secret)

## A note on the "reason"

The reason for the market's move is AI-generated financial reasoning based on the day's price data, not a live news lookup — treat it as a plausible explanation, not a sourced fact.

## License

MIT
