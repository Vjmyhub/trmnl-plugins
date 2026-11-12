# Market Brief 📈 — TRMNL Plugin

Your daily briefing on one e-ink display: 1-day and 5-day market trend, real financial headlines on why the market's moving, trending stocks, S&P 500 / Dow Jones / Nasdaq status, and JPMorgan (JPM) stock — updated automatically after each US market close.

## How it works

```
GitHub Action (scheduled) → fetches S&P 500 + Dow + Nasdaq + JPM quotes (1D + 5D trend) + real news headlines + trending tickers → POSTs to TRMNL webhook → your e-ink display
```

No server needed, no API key, no billing — it runs entirely on free GitHub Actions, free Yahoo Finance endpoints, and free RSS feeds. All text shown (headlines, trending tickers) is real data shown verbatim — no AI paraphrasing or synthesis.

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

> Note: GitHub auto-disables scheduled workflows after 60 days of repo inactivity. If pushes stop appearing, check the Actions tab (or an email from GitHub) and re-enable the workflow there.

## What it shows

- **Trend**: S&P 500, Dow Jones, Nasdaq, and JPMorgan (JPM) — each with both 1-day and 5-day (trading week) price, % change, and direction
- **Trend summary**: a rule-based one-line read for *each* of the 4 instruments (e.g. "Dow Jones dipped today despite a stronger week") computed from the real 1-day vs. 5-day direction — not AI-generated, just plain comparison logic
- **Market news**: up to four real headlines pulled from financial news feeds, shown as-is
- **Trending today**: the top stocks currently trending in search/interest (via Yahoo Finance's public trending list), each shown with its real 1-day % change — informational context on what's getting attention, not a recommendation to buy or sell anything
- A top headline as the daily brief line

## News & data sources

All free, no API key required:
- **Quotes & trend**: Yahoo Finance's public chart endpoint (1-day and 5-day history)
- **Trending tickers**: Yahoo Finance's public trending-tickers endpoint
- **Headlines**: MarketWatch Top Stories, Yahoo Finance News, CNBC Markets RSS feeds

Headlines and trending tickers are shown exactly as published — no AI involved, so there's nothing to pay for or authenticate, and nothing is paraphrased or interpreted.

## Customization

Edit `.github/workflows/push-market-brief.yml` to change:
- **Schedule**: modify the cron expression (`30 21 * * 1-5`)
- **Tickers**: the "Fetch market quotes" step calls `fetch_quote "<symbol>" "<prefix>"` once per instrument — add, remove, or swap tickers there (e.g. `fetch_quote "AAPL" "aapl"`), and add matching fields to the TRMNL payload and `template.liquid`
- **Trending tickers count**: change `count=5` in the "Fetch trending tickers" step's URL
- **News sources**: edit the `feeds` list in the "Fetch market news headlines" step
- **AI-written summaries instead**: if you'd rather have an LLM summarize *why* the market moved instead of showing a raw headline, replace the "Pick reason + brief from real headlines" step with a call to the Claude API (requires an `ANTHROPIC_API_KEY` secret and a Console account with billing enabled) or another provider

## A note on "market news" and "trending today"

These are real headlines and a real trending-tickers list shown verbatim — not analysis, not fact-checked, and not personalized financial advice. The trend summary is plain comparison logic on real numbers (1-day direction vs. 5-day direction), not an AI-generated opinion. "Trending today" reflects what's getting search/news attention, not a buy/sell signal; treat everything here as context to notice, not instructions to act on.

## License

MIT
