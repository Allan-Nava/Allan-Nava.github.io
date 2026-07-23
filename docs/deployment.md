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

Every 3 hours, reads the channel RSS feed (`scripts/sync_youtube.rb`, no API key needed) and creates a blog post for every video/short published in the last 7 days that isn't already embedded in an existing post — hand-written posts are never duplicated, and re-runs are idempotent. New posts are validated with `scripts/validate_posts.rb`, committed by `github-actions[bot]`, pushed, and the deploy workflow is dispatched explicitly (pushes made with `GITHUB_TOKEN` don't fire push-triggered workflows).

Manual runs from the Actions tab accept a `max_age_days` input to backfill recent videos. For the full channel history there is `ruby scripts/backfill_youtube.rb` (one-shot, local): it enumerates every video and short on the channel by paginating the web player's internal API, then creates the missing posts — idempotent, `DRY_RUN=1` and `SINCE=YYYY` supported. Shorts are detected via a HEAD request to `/shorts/<id>` (200 = short, redirect = regular video) and get portrait embed dimensions plus a `short` tag.

### `strava-sync.yml` — Strava Sync

Every 6 hours, creates a blog post for every new Strava activity of the configured types (default: Hike, RockClimbing, TrailRun, Snowboard, AlpineSki) via `scripts/sync_strava.rb`. Same pipeline as the YouTube sync: dedup by activity ID (`strava.com/activities/<id>` in any post), validation, bot commit, explicit deploy dispatch. Until the secrets below are configured, runs exit successfully doing nothing.

**One-time setup:**

1. Create an API application at <https://www.strava.com/settings/api> (category: anything; callback domain: `localhost`). Note the **Client ID** and **Client Secret**.
2. Authorize your own app with read scope: open in the browser
   `https://www.strava.com/oauth/authorize?client_id=<CLIENT_ID>&redirect_uri=http://localhost&response_type=code&scope=activity:read_all`
   and after the approval copy the `code=...` parameter from the URL you land on.
3. Exchange the code for tokens:
   ```bash
   curl -X POST https://www.strava.com/oauth/token \
     -d client_id=<CLIENT_ID> -d client_secret=<CLIENT_SECRET> \
     -d code=<CODE> -d grant_type=authorization_code
   ```
   Save the `refresh_token` from the response.
4. In the repo: Settings → Secrets and variables → Actions → add `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_REFRESH_TOKEN`.

The refresh token never expires (it rotates transparently; the script always exchanges it for a fresh access token at each run).

### `uptime.yml` — Uptime Monitor

Every 10 minutes, curls `https://allan-nava.github.io/` and fails the run if the site doesn't respond with a success status (3 retries). A failing run in the Actions tab means the site is down.

### `lighthouse.yml` — Lighthouse CI

Runs on every pull request and push to master (also `workflow_dispatch`). It builds the site with Jekyll, serves `_site/` locally with `http-server` on port 8080, then runs Google Lighthouse (via `treosh/lighthouse-ci-action`) against the **structural pages** — `/`, `/blog/`, `/projects.html`, `/tags.html`, `/about/`, `/map/`, `/fitness/`, `/gear/`. Individual posts are deliberately excluded so the budget isn't coupled to content. Reports are uploaded to Lighthouse's temporary public storage (a link appears in the run log).

The build has no `--baseurl`: this is a GitHub user page, so the production base path is empty and the site is served from the local root exactly as in production.

**Budget** — defined in `lighthouserc.json` at the repo root, tuned to *pass on day one and fail only on real regressions*:

| Category | Level | Min score |
|---|---|---|
| `seo` | **error** (hard gate) | 0.85 |
| `accessibility` | warn | 0.90 |
| `best-practices` | warn | 0.90 |
| `performance` | warn | 0.50 |

SEO is the hard gate because `jekyll-seo-tag` makes it reliably high — a failure means something real broke (meta tags removed, plugin gone). The other categories start as **warnings** so the job never red-fails on introduction. **Once a few green runs establish the real baseline scores, promote `accessibility`/`best-practices`/`performance` from `warn` to `error`** (and raise the thresholds) in `lighthouserc.json` — that's the whole point of the budget. The action uses Ruby 3.0 pinned to the same `ruby/setup-ruby` release as `jekyll.yml`/`checks.yml`; keep them in sync.

`lighthouserc.json` and `AGENTS.md` are listed in `_config.yml` `exclude:` so they are not copied into the published site.

### `bootstrap-milestone.yml` — Bootstrap milestone

Run manually from the Actions tab (`workflow_dispatch` only). Using `actions/github-script`, it creates the **versioned backlog milestones** (`v2.0` Performance & Navigazione, `v2.1` Contenuti & Engagement, `v2.2` Automazioni & Platform, `v3.0` Big rocks) and one issue per item in [ROADMAP](ROADMAP.md), each assigned to its milestone. It is idempotent: existing milestones/issues with the same title are skipped, and an issue found under the wrong milestone is moved to the right one — so after adding items to ROADMAP.md (mirrored in the workflow's `BACKLOG` array), re-running creates only the new ones. It needs `issues: write` and touches nothing else in the repo.

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
