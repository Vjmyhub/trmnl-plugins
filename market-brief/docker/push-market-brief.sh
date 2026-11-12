#!/usr/bin/env bash
# Standalone version of .github/workflows/push-market-brief.yml's logic,
# for running outside GitHub Actions (e.g. cron inside a Docker container).
#
# Requires: bash, curl, jq, awk, python3
# Requires env var: MARKET_BRIEF_WEBHOOK_URL

set -u
set +e

if [ -z "${MARKET_BRIEF_WEBHOOK_URL:-}" ]; then
  echo "ERROR: MARKET_BRIEF_WEBHOOK_URL is not set" >&2
  exit 1
fi

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

# ---------------------------------------------------------------------------
# 1. Fetch market quotes (S&P 500, Dow, Nasdaq, JPM) — 1-day and 5-day trend
# ---------------------------------------------------------------------------
fetch_quote() {
  local symbol="$1"
  local prefix="$2"
  local response price prev change dir week_prev week_change week_dir

  response=$(curl -s -H "User-Agent: Mozilla/5.0" \
    "https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=5d")
  price=$(echo "$response" | jq -r '.chart.result[0].meta.regularMarketPrice // empty' 2>/dev/null)
  prev=$(echo "$response" | jq -r '.chart.result[0].meta.chartPreviousClose // empty' 2>/dev/null)
  week_prev=$(echo "$response" | jq -r '[.chart.result[0].indicators.quote[0].close[]? ] | map(select(. != null)) | .[0] // empty' 2>/dev/null)

  if [ -z "$price" ] || [ -z "$prev" ]; then
    log "WARNING: failed to fetch $symbol quote — using fallback values"
    price="N/A"
    change="0.00"
    dir="flat"
    week_change="0.00"
    week_dir="flat"
  else
    change=$(awk -v p="$price" -v prev="$prev" 'BEGIN{printf "%+.2f", ((p-prev)/prev)*100}')
    dir=$(awk -v p="$price" -v prev="$prev" 'BEGIN{ if (p>prev) print "up"; else if (p<prev) print "down"; else print "flat" }')

    if [ -z "$week_prev" ]; then
      week_change="0.00"
      week_dir="flat"
    else
      week_change=$(awk -v p="$price" -v prev="$week_prev" 'BEGIN{printf "%+.2f", ((p-prev)/prev)*100}')
      week_dir=$(awk -v p="$price" -v prev="$week_prev" 'BEGIN{ if (p>prev) print "up"; else if (p<prev) print "down"; else print "flat" }')
    fi
  fi

  eval "${prefix}_PRICE=\"\$price\""
  eval "${prefix}_CHANGE=\"\$change\""
  eval "${prefix}_DIR=\"\$dir\""
  eval "${prefix}_WEEK_CHANGE=\"\$week_change\""
  eval "${prefix}_WEEK_DIR=\"\$week_dir\""
}

log "Fetching market quotes..."
fetch_quote "%5EGSPC" "SP"
fetch_quote "%5EDJI" "DOW"
fetch_quote "%5EIXIC" "NASDAQ"
fetch_quote "JPM" "JPM"

# ---------------------------------------------------------------------------
# 2. Fetch trending tickers, enriched with each ticker's 1-day % change
# ---------------------------------------------------------------------------
log "Fetching trending tickers..."
RESPONSE=$(curl -s -H "User-Agent: Mozilla/5.0" \
  "https://query1.finance.yahoo.com/v1/finance/trending/US?count=5")
TICKERS=$(echo "$RESPONSE" | jq -c '[.finance.result[0].quotes[]?.symbol] // []' 2>/dev/null)

if [ -z "$TICKERS" ] || [ "$TICKERS" = "null" ]; then
  log "WARNING: failed to fetch trending tickers — using empty list"
  TICKERS="[]"
fi

MOVERS="[]"
if [ "$TICKERS" != "[]" ]; then
  MOVER_LIST=()
  for symbol in $(echo "$TICKERS" | jq -r '.[]'); do
    QRESP=$(curl -s -H "User-Agent: Mozilla/5.0" \
      "https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=1d")
    QPRICE=$(echo "$QRESP" | jq -r '.chart.result[0].meta.regularMarketPrice // empty' 2>/dev/null)
    QPREV=$(echo "$QRESP" | jq -r '.chart.result[0].meta.chartPreviousClose // empty' 2>/dev/null)
    if [ -n "$QPRICE" ] && [ -n "$QPREV" ]; then
      QCHANGE=$(awk -v p="$QPRICE" -v prev="$QPREV" 'BEGIN{printf "%+.1f", ((p-prev)/prev)*100}')
      MOVER_LIST+=("${symbol} ${QCHANGE}%")
    else
      MOVER_LIST+=("${symbol}")
    fi
  done
  MOVERS=$(printf '%s\n' "${MOVER_LIST[@]}" | jq -R . | jq -cs .)
fi
TRENDING_TEXT=$(echo "$MOVERS" | jq -r 'if length > 0 then join(" · ") else "No standout movers today" end' 2>/dev/null)

# ---------------------------------------------------------------------------
# 3. Fetch market news headlines (title + short excerpt, real RSS content)
# ---------------------------------------------------------------------------
log "Fetching market news headlines..."
HEADLINES=$(python3 <<'PY'
import json
import re
import urllib.request
import xml.etree.ElementTree as ET

feeds = [
    "https://feeds.marketwatch.com/marketwatch/topstories/",
    "https://finance.yahoo.com/news/rssindex",
    "https://www.cnbc.com/id/20910258/device/rss/rss.html",
]

def clean_html(text):
    text = re.sub(r'<[^>]+>', '', text)
    text = (text.replace('&nbsp;', ' ').replace('&amp;', '&')
                .replace('&#39;', "'").replace('&quot;', '"'))
    return re.sub(r'\s+', ' ', text).strip()

def truncate(text, limit=160):
    if len(text) <= limit:
        return text
    return text[:limit].rsplit(' ', 1)[0] + '...'

headlines = []
seen_titles = set()
for url in feeds:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read()
        root = ET.fromstring(data)
        for item in root.iter("item"):
            title_el = item.find("title")
            desc_el = item.find("description")
            if title_el is not None and title_el.text:
                title = title_el.text.strip()
                if not title or title in seen_titles:
                    continue
                description = ""
                if desc_el is not None and desc_el.text:
                    cleaned = clean_html(desc_el.text)
                    if cleaned and cleaned != title:
                        description = truncate(cleaned)
                seen_titles.add(title)
                headlines.append({"title": title, "description": description})
    except Exception:
        continue

print(json.dumps(headlines[:10]))
PY
)

# ---------------------------------------------------------------------------
# 4. Pick reason + brief from real headlines
# ---------------------------------------------------------------------------
BRIEF=$(echo "$HEADLINES" | jq -r '.[0].title // empty')
WHY1=$(echo "$HEADLINES" | jq -r '.[1].title // empty')
WHY1_DESC=$(echo "$HEADLINES" | jq -r '.[1].description // empty')
WHY2=$(echo "$HEADLINES" | jq -r '.[2].title // empty')
WHY2_DESC=$(echo "$HEADLINES" | jq -r '.[2].description // empty')
WHY3=$(echo "$HEADLINES" | jq -r '.[3].title // empty')
WHY4=$(echo "$HEADLINES" | jq -r '.[4].title // empty')

if [ -z "$BRIEF" ]; then
  BRIEF="No headlines available today — check the container logs."
fi
if [ -z "$WHY1" ]; then
  WHY1="Check the market for today's developments."
fi

# ---------------------------------------------------------------------------
# 5. Build trend summaries and push to TRMNL
# ---------------------------------------------------------------------------
DATE=$(date -u '+%b %d, %Y')
TIME=$(date -u '+%I:%M %p UTC')
UTC_HOUR=$(date -u '+%H')
if [ "$UTC_HOUR" -lt 16 ]; then
  PERIOD="Market Open"
elif [ "$UTC_HOUR" -lt 19 ]; then
  PERIOD="Midday"
else
  PERIOD="Market Close"
fi

trend_line() {
  local name="$1" dir="$2" week_dir="$3"
  if [ "$dir" = "up" ] && [ "$week_dir" = "up" ]; then
    echo "📈 ${name} is climbing — up today and up this week."
  elif [ "$dir" = "up" ] && [ "$week_dir" = "down" ]; then
    echo "📈 ${name} bounced today after a down week."
  elif [ "$dir" = "down" ] && [ "$week_dir" = "up" ]; then
    echo "📉 ${name} dipped today despite a stronger week."
  elif [ "$dir" = "down" ] && [ "$week_dir" = "down" ]; then
    echo "📉 ${name} is sliding — down today and down this week."
  else
    echo "▪ ${name} is roughly flat today and this week."
  fi
}

SP_TREND=$(trend_line "S&P 500" "$SP_DIR" "$SP_WEEK_DIR")
DOW_TREND=$(trend_line "Dow Jones" "$DOW_DIR" "$DOW_WEEK_DIR")
NASDAQ_TREND=$(trend_line "Nasdaq" "$NASDAQ_DIR" "$NASDAQ_WEEK_DIR")
JPM_TREND=$(trend_line "JPMorgan" "$JPM_DIR" "$JPM_WEEK_DIR")

PAYLOAD=$(jq -n \
  --arg date "$DATE" \
  --arg time "$TIME" \
  --arg period "$PERIOD" \
  --arg brief "$BRIEF" \
  --arg why1 "$WHY1" \
  --arg why1_desc "$WHY1_DESC" \
  --arg why2 "$WHY2" \
  --arg why2_desc "$WHY2_DESC" \
  --arg why3 "$WHY3" \
  --arg why4 "$WHY4" \
  --arg trending "$TRENDING_TEXT" \
  --arg sp_trend "$SP_TREND" \
  --arg dow_trend "$DOW_TREND" \
  --arg nasdaq_trend "$NASDAQ_TREND" \
  --arg jpm_trend "$JPM_TREND" \
  --arg sp_price "$SP_PRICE" \
  --arg sp_change "$SP_CHANGE" \
  --arg sp_dir "$SP_DIR" \
  --arg sp_week_change "$SP_WEEK_CHANGE" \
  --arg sp_week_dir "$SP_WEEK_DIR" \
  --arg dow_price "$DOW_PRICE" \
  --arg dow_change "$DOW_CHANGE" \
  --arg dow_dir "$DOW_DIR" \
  --arg dow_week_change "$DOW_WEEK_CHANGE" \
  --arg dow_week_dir "$DOW_WEEK_DIR" \
  --arg nasdaq_price "$NASDAQ_PRICE" \
  --arg nasdaq_change "$NASDAQ_CHANGE" \
  --arg nasdaq_dir "$NASDAQ_DIR" \
  --arg nasdaq_week_change "$NASDAQ_WEEK_CHANGE" \
  --arg nasdaq_week_dir "$NASDAQ_WEEK_DIR" \
  --arg jpm_price "$JPM_PRICE" \
  --arg jpm_change "$JPM_CHANGE" \
  --arg jpm_dir "$JPM_DIR" \
  --arg jpm_week_change "$JPM_WEEK_CHANGE" \
  --arg jpm_week_dir "$JPM_WEEK_DIR" \
  '{merge_variables: {
    date: $date,
    time: $time,
    period: $period,
    brief: $brief,
    why1: $why1,
    why1_desc: $why1_desc,
    why2: $why2,
    why2_desc: $why2_desc,
    why3: $why3,
    why4: $why4,
    trending: $trending,
    sp_trend: $sp_trend,
    dow_trend: $dow_trend,
    nasdaq_trend: $nasdaq_trend,
    jpm_trend: $jpm_trend,
    market_index_name: "S&P 500",
    market_price: $sp_price,
    market_change_pct: $sp_change,
    market_direction: $sp_dir,
    market_week_change_pct: $sp_week_change,
    market_week_direction: $sp_week_dir,
    dow_price: $dow_price,
    dow_change_pct: $dow_change,
    dow_direction: $dow_dir,
    dow_week_change_pct: $dow_week_change,
    dow_week_direction: $dow_week_dir,
    nasdaq_price: $nasdaq_price,
    nasdaq_change_pct: $nasdaq_change,
    nasdaq_direction: $nasdaq_dir,
    nasdaq_week_change_pct: $nasdaq_week_change,
    nasdaq_week_direction: $nasdaq_week_dir,
    jpm_price: $jpm_price,
    jpm_change_pct: $jpm_change,
    jpm_direction: $jpm_dir,
    jpm_week_change_pct: $jpm_week_change,
    jpm_week_direction: $jpm_week_dir
  }}')

log "Pushing to TRMNL..."
HTTP_STATUS=$(curl -s -o /tmp/trmnl-response.txt -w "%{http_code}" -X POST "$MARKET_BRIEF_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

cat /tmp/trmnl-response.txt
echo
if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
  log "ERROR: TRMNL webhook returned HTTP $HTTP_STATUS"
  exit 1
fi
log "Done! (HTTP $HTTP_STATUS)"
