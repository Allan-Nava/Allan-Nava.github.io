# Deployment & CI

The site deploys to **GitHub Pages** through GitHub Actions (not the legacy Pages branch build). All workflows live in `.github/workflows/`.

## Workflows

### `jekyll.yml` — Deploy Jekyll site to Pages

- **Triggers**: push to `master`, daily cron (`0 10 * * *`), manual (`workflow_dispatch`). The daily rebuild publishes future-dated posts without needing a push.
- **Build job**: checkout → Ruby 3.0 with cached bundle → `actions/configure-pages` → `bundle exec jekyll build --baseurl <pages base path>` with `JEKYLL_ENV=production` → upload `_site/` as a Pages artifact.
- **Deploy job**: `actions/deploy-pages` publishes the artifact to the `github-pages` environment.

The `pages` concurrency group with `cancel-in-progress: true` ensures simultaneous runs don't race: the newer run cancels the older one.

The Ruby version in the workflow must stay in sync with `Gemfile.lock` — bump them together when updating the `github-pages` gem.

### `checks.yml` — Checks

Runs on every pull request and push to master, with two parallel jobs:

- **validate** — `ruby scripts/validate_posts.rb` (front matter sanity: parseable YAML, plausible dates, non-empty titles, known category/author, referenced asset files exist, no `github.com/...blob` hotlinks) plus a YAML parse of `_config.yml` and all workflows. Runs on the system Ruby, no bundle needed — this is the fast fail.
- **build** — full `jekyll build` followed by html-proofer restricted to internal links and images (external links are skipped: old posts point at long-dead sites).

This is what makes Dependabot gem-bump PRs safe to merge: a red check means the bump breaks the build. The Ruby setup is intentionally identical to `jekyll.yml` — keep them in sync. The validator also runs as a gate inside the deploy workflow, so a broken post stops a deploy before it publishes.

Run the validator locally anytime with `ruby scripts/validate_posts.rb` (stdlib only, no bundle needed).

### `youtube-sync.yml` — YouTube Sync

Every 6 hours, reads the channel RSS feed (`scripts/sync_youtube.rb`, no API key needed) and creates a blog post for every video/short published in the last 7 days that isn't already embedded in an existing post — hand-written posts are never duplicated, and re-runs are idempotent. New posts are validated with `scripts/validate_posts.rb`, committed by `github-actions[bot]`, pushed, and the deploy workflow is dispatched explicitly (pushes made with `GITHUB_TOKEN` don't fire push-triggered workflows).

Manual runs from the Actions tab accept a `max_age_days` input to backfill older videos. Shorts are detected via the oEmbed player orientation and get portrait embed dimensions plus a `short` tag.

### `uptime.yml` — Uptime Monitor

Every 10 minutes, curls `https://allan-nava.github.io/` and fails the run if the site doesn't respond with a success status (3 retries). A failing run in the Actions tab means the site is down.

## Publishing flow

1. Commit content/changes to `master` (there is no `main` branch in practice — `master` is the default).
2. Push. The deploy workflow fires and the deploy job prints the live URL in its environment summary.

No build output is ever committed: `_site/` is git-ignored and exists only inside CI or your local checkout.

## Known limitation: LFS videos

`actions/checkout` does **not** download Git LFS objects, so any `.MOV` under `assets/video/` reaches the published site as a tiny LFS pointer text file — a local `/assets/video/x.MOV` embed appears broken. Existing posts work around this by linking videos through `github.com/<repo>/raw/master/...`, which GitHub redirects to `media.githubusercontent.com` serving the real LFS content — those embeds work, but every view consumes the free LFS bandwidth quota (1 GB/month); if it runs out, all videos break until the quota resets. Don't add new self-hosted videos either way: upload them to YouTube and embed the player instead (see [Writing Content](writing-content.md)). Enabling `lfs: true` in the CI checkout is not a fix — with ~700 MB of videos, the daily build would exhaust the quota immediately.

## Pre-push checks

```bash
rake test        # jekyll build + html-proofer on _site/ (reports 4xx broken links)
```

Old posts link to sites that no longer exist, so scope any fixes to internal links, images, and pages you actually touched.
