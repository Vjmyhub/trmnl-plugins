# Market Brief 📈 — TRMNL Plugin

Your daily briefing on one e-ink display: real financial headlines, S&P 500 status, and JPMorgan (JPM) stock — updated automatically after each US market close.

## How it works

```
GitHub Action (scheduled) → fetches S&P 500 + JPM quotes + real news headlines → POSTs to TRMNL webhook → your e-ink display
```

No server needed, no API key, no billing — it runs entirely on free GitHub Actions and free RSS feeds. The two top real headlines of the day are shown verbatim (no AI paraphrasing).

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

### 3. Add the webhook secret

1. Go to your fork → **Settings** → **Secrets and variables** → **Actions**
2. Add a new secret:
   - Name: `MARKET_BRIEF_WEBHOOK_URL`
   - Value: your webhook URL from step 1

> Uses a distinct secret name from the other plugins so you can run several private plugins from the same fork at once.

### 4. Enable the GitHub Action

The Action runs weekdays at 21:30 UTC (shortly after the 4:00pm ET US market close). You can also trigger it manually from the **Actions** tab.

## What it shows

- Today's top real financial headline as the "reason" line
- A second real headline as the daily brief line
- S&P 500: price, % change, direction
- JPMorgan (JPM): price, % change, direction

## News sources

Headlines are pulled from free, no-key-required RSS feeds:
- MarketWatch Top Stories
- Yahoo Finance News
- CNBC Markets

The first two headlines collected (in feed order) are used as-is — no AI is involved, so there's nothing to pay for or authenticate.

## Customization

Edit `.github/workflows/push-market-brief.yml` to change:
- **Schedule**: modify the cron expression (`30 21 * * 1-5`)
- **Tickers**: change `%5EGSPC` (S&P 500) or `JPM` in the Yahoo Finance URLs to track other indices/stocks
- **News sources**: edit the `feeds` list in the "Fetch market news headlines" step
- **AI-written summaries instead**: if you'd rather have an LLM summarize *why* the market moved instead of showing a raw headline, replace the "Pick reason + brief from real headlines" step with a call to the Claude API (requires an `ANTHROPIC_API_KEY` secret and a Console account with billing enabled) or another provider

## A note on the "reason"

The reason and brief are real headlines shown exactly as published by the source feed — not analysis, not fact-checked, and not necessarily about *why* the market moved (they're simply the top items from that day's feed).

## License

MIT
