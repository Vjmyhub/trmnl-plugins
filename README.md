# TRMNL Plugins ⬛

A collection of community plugins for [TRMNL](https://usetrmnl.com) e-ink displays. No servers needed — each plugin is a Liquid template + webhook automation.

## Plugins

| Plugin | Description |
|--------|-------------|
| [**GitHub Stars ⭐**](github-stars/) | Top 5 most starred repos on GitHub |
| [**Agent Says 🤖**](agent-says/) | Daily AI agent quotes + priorities |
| [**Market Brief 📈**](market-brief/) | S&P 500 + JPM stock status with real financial headlines, no API key needed |

## How it works

Each plugin folder contains:
- `template.liquid` — paste into your TRMNL Private Plugin markup
- `README.md` — setup instructions

All plugins use the **Webhook** strategy: set up a cron job or GitHub Action to POST data to your plugin's webhook URL.

## Quick Start

1. Pick a plugin from the table above
2. Create a **Private Plugin** on [trmnl.com](https://trmnl.com) → Webhook strategy
3. Paste the `template.liquid` into the Markup field
4. Follow the plugin's README to set up data automation

## Contributing

Want to add a plugin? Create a folder with `template.liquid` + `README.md` and open a PR.

## License

MIT
