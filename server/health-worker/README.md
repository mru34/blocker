# Rule health worker

Collects the app's anonymous daily rule-health counts (posts seen, reels hidden, which selectors
matched) and opens a GitHub issue on `mru34/blocker` when a rule looks broken, usually because
Instagram or YouTube changed their site. GitHub emails you about new issues.

The app only sends reports when the rules file has a `healthReportURL`, so nothing is sent until
this is deployed and that URL is added to the gist.

## Deploy (free Cloudflare account)

```sh
cd server/health-worker
npx wrangler login                        # opens the browser
npx wrangler kv namespace create REPORTS  # paste the printed id into wrangler.toml
npx wrangler secret put GITHUB_TOKEN      # fine-grained token: Issues read/write on mru34/blocker only
npx wrangler deploy                       # prints https://blocker-health.<you>.workers.dev
```

Then add `"healthReportURL": "https://blocker-health.<you>.workers.dev/report"` at the top level
of `rules.json` in the gist (and bump `version`).

## What it checks (daily, for yesterday)

- A site's feed showed 100+ posts across all phones but no reel was hidden: `collapseSelectors`
  probably stopped matching.
- A `hideSelectors` / `collapseSelectors` entry matched nothing on any of 3+ phones.
