# Market Brief 📈 — TRMNL Plugin

Your daily briefing on one e-ink display: a short AI-written note, S&P 500 status, why the market moved, and JPMorgan (JPM) stock — updated automatically after each US market close.

## How it works

```
GitHub Action (scheduled) → fetches S&P 500 + JPM quotes + real news headlines → AI writes reason + brief → POSTs to TRMNL webhook → your e-ink display
```

No server needed — it runs entirely on GitHub Actions using the Claude API to write the reason/brief text.

> **Note:** this previously used free GitHub Models, but GitHub has retired that feature, so it now requires your own Anthropic API key (step 3 below). Usage is tiny — one short call per weekday — so cost should be a few cents a month at most.

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

### 3. Add two secrets

1. Go to your fork → **Settings** → **Secrets and variables** → **Actions**
2. Add:
   - `MARKET_BRIEF_WEBHOOK_URL` — the TRMNL webhook URL from step 1
   - `ANTHROPIC_API_KEY` — an API key from [console.anthropic.com](https://console.anthropic.com)

> `MARKET_BRIEF_WEBHOOK_URL` uses a distinct name from the other plugins so you can run several private plugins from the same fork at once.

### 4. Enable the GitHub Action

The Action runs weekdays at 21:30 UTC (shortly after the 4:00pm ET US market close). You can also trigger it manually from the **Actions** tab.

## What it shows

- A short AI-written daily brief line
- S&P 500: price, % change, direction, and a one-sentence reason for the move — grounded in real headlines from the day's financial news
- JPMorgan (JPM): price, % change, direction

## News sources

Headlines are pulled from free, no-key-required RSS feeds:
- MarketWatch Top Stories
- Yahoo Finance News
- CNBC Markets

The AI step is given these headlines and asked to pick the most relevant one(s) to explain the day's move. If none of the pulled headlines are relevant, it falls back to a brief general explanation instead of forcing a connection.

## Customization

Edit `.github/workflows/push-market-brief.yml` to change:
- **Schedule**: modify the cron expression (`30 21 * * 1-5`)
- **Tickers**: change `%5EGSPC` (S&P 500) or `JPM` in the Yahoo Finance URLs to track other indices/stocks
- **News sources**: edit the `feeds` list in the "Fetch market news headlines" step
- **AI model**: the "Generate brief + reason" step uses `claude-haiku-4-5-20251001` — change the `model` field in the step's payload to use a different Claude model

## A note on the "reason"

The reason is AI-summarized from real headlines pulled at run time, not independently fact-checked — treat it as a best-effort explanation grounded in the day's news, not a verified analysis.

## License

MIT
