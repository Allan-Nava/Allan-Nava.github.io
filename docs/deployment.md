# Deployment & CI

The site deploys to **GitHub Pages** through GitHub Actions (not the legacy Pages branch build). All workflows live in `.github/workflows/`.

## Workflows

### `jekyll.yml` — Deploy Jekyll site to Pages

- **Triggers**: push to `master`, daily cron (`0 10 * * *`), manual (`workflow_dispatch`). The daily rebuild publishes future-dated posts without needing a push.
- **Build job**: checkout → Ruby 3.0 with cached bundle → `actions/configure-pages` → `bundle exec jekyll build --baseurl <pages base path>` with `JEKYLL_ENV=production` → upload `_site/` as a Pages artifact.
- **Deploy job**: `actions/deploy-pages` publishes the artifact to the `github-pages` environment.

The `pages` concurrency group with `cancel-in-progress: true` ensures simultaneous runs don't race: the newer run cancels the older one.

The Ruby version in the workflow must stay in sync with `Gemfile.lock` — bump them together when updating the `github-pages` gem.

### `uptime.yml` — Uptime Monitor

Every 10 minutes, curls `https://allan-nava.github.io/` and fails the run if the site doesn't respond with a success status (3 retries). A failing run in the Actions tab means the site is down.

## Publishing flow

1. Commit content/changes to `master` (there is no `main` branch in practice — `master` is the default).
2. Push. The deploy workflow fires and the deploy job prints the live URL in its environment summary.

No build output is ever committed: `_site/` is git-ignored and exists only inside CI or your local checkout.

## Known limitation: LFS videos

`actions/checkout` does **not** download Git LFS objects, so any `.MOV` under `assets/video/` reaches the published site as a tiny LFS pointer text file — the video appears broken. Don't add new self-hosted videos: upload them to YouTube and embed the player instead (see [Writing Content](writing-content.md)). Enabling `lfs: true` in the checkout is not a fix — with ~700 MB of videos, the daily build would exhaust the free LFS bandwidth quota (1 GB/month) immediately.

## Pre-push checks

```bash
rake test        # jekyll build + html-proofer on _site/ (reports 4xx broken links)
```

Old posts link to sites that no longer exist, so scope any fixes to internal links, images, and pages you actually touched.
