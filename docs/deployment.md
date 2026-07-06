# Deployment & CI

The site deploys to **GitHub Pages** through GitHub Actions (not the legacy Pages branch build). All workflows live in `.github/workflows/`.

## Workflows

### `jekyll.yml` — Deploy Jekyll site to Pages

- **Triggers**: push to `master`, manual (`workflow_dispatch`).
- **Build job**: checkout → Ruby 3.0 with cached bundle → `actions/configure-pages` → `bundle exec jekyll build --baseurl <pages base path>` with `JEKYLL_ENV=production` → upload `_site/` as a Pages artifact.
- **Deploy job**: `actions/deploy-pages` publishes the artifact to the `github-pages` environment.

### `refresh.yml` — Build and deploy | Refresh

Identical build/deploy pipeline, with two extra triggers:

- **Daily cron** (`0 10 * * *`) — rebuilds the site every day so time-dependent content (e.g. future-dated posts) is published without a push.
- Push to `master`/`main`.

Both workflows share the `pages` concurrency group with `cancel-in-progress: true`, so simultaneous runs don't race: the newer run cancels the older one.

### `uptime.yml` — Uptime Monitor

Every 10 minutes, pings `https://allan-nava.github.io/` and expects HTTP 200 (via `srt32/uptime`). A failing run in the Actions tab means the site is down.

## Publishing flow

1. Commit content/changes to `master` (there is no `main` branch in practice — `master` is the default).
2. Push. Both deploy workflows fire; the concurrency group lets the last one win.
3. The deploy job prints the live URL in its environment summary.

No build output is ever committed: `_site/` is git-ignored and exists only inside CI or your local checkout.

## Pre-push checks

```bash
rake test        # jekyll build + html-proofer on _site/ (all checks, verbose)
./travis.sh      # jekyll build + html-proofer, only 4xx link errors
```

`travis.sh` is a leftover from the Travis CI era but remains the quickest sanity check before pushing. Old posts link to sites that no longer exist, so scope any fixes to internal links, images, and pages you actually touched.
