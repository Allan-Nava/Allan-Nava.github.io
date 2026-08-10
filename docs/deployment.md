# Deployment & CI

The site deploys to **GitHub Pages** through GitHub Actions (not the legacy Pages branch build). All workflows live in `.github/workflows/`.

## Workflows

### `jekyll.yml` — Deploy Jekyll site to Pages

- **Triggers**: push to `master`, daily cron (`0 10 * * *`), manual (`workflow_dispatch`). The daily rebuild publishes future-dated posts without needing a push. **Not** tags or releases: the `github-pages` environment only accepts the default branch, so a tag-triggered run dies with `Tag vX.Y.Z is not allowed to deploy to github-pages` — and worse, the `pages` concurrency group (`cancel-in-progress: true`) makes it cancel the legitimate master deploy first. That happened with `v2.4.0`: the push published nothing. Releases are handled by `release.yml`, which never touches Pages.
- **Build job**: checkout → Ruby 3.0 with cached bundle → `actions/configure-pages` → `bundle exec jekyll build --baseurl <pages base path>` with `JEKYLL_ENV=production` → upload `_site/` as a Pages artifact.
- **Deploy job**: `actions/deploy-pages` publishes the artifact to the `github-pages` environment.
- **Smoke job**: after the deploy, [checkfleet](https://github.com/Allan-Nava/checkfleet) probes the **live** site (`checkfleet check http --config checkfleet.yml`) and attaches its Markdown report to the job summary.

The smoke job closes a real gap: `checks.yml` validates the locally built `_site` *before* the deploy, so nothing else ever reads what Pages actually serves — a deploy that reported success while serving a wrong or partial page used to go unnoticed. It can't gate the deploy (that already happened); it exists to notify. Details of the target list are in [`checkfleet.yml`](../checkfleet.yml) at the repo root.

Two implementation details that are load-bearing:

- The step declares `shell: bash` so that **pipefail** is on. Without it, piping into `tee` for the job summary masks checkfleet's `--exit-on-bad` exit code with `tee`'s own `0`, and the job would never fail (verified: exit 2 with pipefail, exit 0 without).
- checkfleet is installed from a **pinned release tarball** (no Go toolchain needed). Keep the version in sync with `uptime.yml`.

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

Manual runs from the Actions tab accept a `max_age_days` input to backfill recent videos. For the full channel history there is `ruby scripts/backfill_youtube.rb` (one-shot, local): it enumerates every video and short on the channel by paginating the web player's internal API, then creates the missing posts — idempotent, `DRY_RUN=1` and `SINCE=YYYY` supported. Shorts are detected via a HEAD request to `/shorts/<id>` (200 = short, redirect = regular video) and get the `data-short` (portrait) facade plus a `short` tag.

Generated posts embed the video with the `<lite-youtube>` facade (not a raw iframe — see [Architecture](architecture.md)) and set the YouTube thumbnail as `image:` for og:image/listing previews. `scripts/migrate_youtube_embeds.rb` is a one-shot that converted the pre-existing iframe embeds to the same facade (`DRY_RUN=1` supported, idempotent).

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

### `github-sync.yml` — GitHub Projects Sync

Hourly (`29 * * * *`), syncs the public repos of the sources configured in `_data/github_sync.yml` — currently the `Allan-Nava` user and the `hiway-media` org — into project posts (listed on `/projects`) via `scripts/sync_github.rb`. Each run does two things:

- **Create** — a new repo gets a post within the hour.
- **Update** — a repo that already has a *generated* post (identified by its `github: <full_name>` marker) is refreshed when it changed: the post tracks the repo's **last push** (`updated:` front matter + an "Ultimo push" line), plus description, language, topics and stars. This is how the sync reacts to pushes on existing repos. The original `date:` (and post URL) is always preserved; **hand-written project posts — those without the marker — are never touched.**

Files are rewritten only when the regenerated content actually differs, so an idle run (no new repo, no push) leaves `_posts` unchanged → the commit step (`git status --porcelain _posts`) is a no-op and nothing deploys. The first run after this feature shipped rewrites every existing generated post once (to add the `updated:`/push fields). Same pipeline as the other syncs: validation, bot commit, explicit deploy dispatch. Forks are always skipped; by default repos without a description are too (`require_description`), and `min_stars` can raise the bar. Dedup is threefold: repo URL already in a post, `github: <full_name>` front-matter marker, or repo name already part of an existing post filename. **To permanently ban a repo, add it to `exclude` in `_data/github_sync.yml`** — deleting the generated post alone is not enough, the next run would recreate it.

### `robots-sync.yml` — Robots Sitemaps Sync

Daily (`0 4 * * *`), keeps the per-project `Sitemap:` lines in `robots.txt` in sync with what is actually published, via `scripts/sync_robots_sitemaps.rb`. The script lists the `Allan-Nava`-owned repos with GitHub Pages enabled (config `_data/robots_sync.yml`), probes `https://allan-nava.github.io/<repo>/sitemap.xml`, and writes the ones that return **200** to `_data/pages_sitemaps.yml`. `robots.txt` (a Liquid template) renders one line per entry plus the fixed host sitemap.

Only the owner's own Pages sites belong here: `robots.txt` is read per-host, and repos owned by a different account/org (e.g. the `hiway-media` org, which does appear in `github_sync.yml` for project *posts*) publish to a different host — hence a single `owner`, not the multi-source list of the projects sync. Repos with a custom domain serve their Pages elsewhere, so the on-host probe 404s and they drop out naturally; no special-casing. As of the last sync, `checkfleet` and `Hugo-TuttoCampo` were the only two Pages sites shipping a sitemap (the rest render a README through a theme). The data file is rewritten only when the live set changes, so an idle run is a no-op → the commit step (`git status --porcelain _data/pages_sitemaps.yml`) skips and nothing deploys. Same pipeline as the other syncs: bot commit + explicit deploy dispatch.

### `uptime.yml` — Uptime Monitor

Every 10 minutes, runs [checkfleet](https://github.com/Allan-Nava/checkfleet) against the live site with the same target list as the post-deploy smoke job (`checkfleet.yml`), failing the run on any BAD/ERROR finding. A failing run in the Actions tab means the site is down **or** one of the checked pages broke on its own — an expired permalink, a broken feed, `404.html` starting to answer `200`.

It previously curled only the homepage; the target list widens that to every structural page plus `feed.xml`, `sitemap.xml`, `robots.txt` and a must-not-exist URL. Output is plain text to the run log with no job summary: this fires 144 times a day, and a summary on every green run is noise — the signal is the failure notification.

**What this is not**: GitHub's scheduled cron has 5-minute granularity with real delays of 10–20 minutes under load, so this is a coarse safety net, not an SLA monitor. Real uptime figures need an external prober, not Actions.

### `lighthouse.yml` — Lighthouse CI

Runs on every pull request and push to master (also `workflow_dispatch`). It builds the site with Jekyll, serves `_site/` locally with `http-server` on port 8080, then runs Google Lighthouse (via `treosh/lighthouse-ci-action`) against the **structural pages** — `/`, `/blog/`, `/projects.html`, `/tags.html`, `/about/`, `/map/`, `/fitness/`, `/gear/`. Individual posts are deliberately excluded so the budget isn't coupled to content. Reports are uploaded to Lighthouse's temporary public storage (a link appears in the run log).

The build has no `--baseurl`: this is a GitHub user page, so the production base path is empty and the site is served from the local root exactly as in production.

**Budget** — defined in `lighthouserc.json` at the repo root, tuned to *pass on day one and fail only on real regressions*:

| Category | Level | Min score |
|---|---|---|
| `seo` | **error** (hard gate) | 0.90 |
| `accessibility` | **error** (hard gate) | 0.95 |
| `best-practices` | **error** (hard gate) | 0.95 |
| `performance` | warn | 0.85 |

SEO, accessibility and best-practices are hard gates: after the v2.3 restyling the structural pages score **100 on all three** (measured locally on `/`, `/blog/`, `/projects.html`, `/tags.html`), so a drop below the threshold is a real regression rather than noise. Performance stays a warning because the score depends on the runner's speed and on page weight — `/tags` renders every post in one page (~350 KB of HTML) and lands around 92 while the other pages sit at 99–100. The action uses Ruby 3.0 pinned to the same `ruby/setup-ruby` release as `jekyll.yml`/`checks.yml`; keep them in sync.

`lighthouserc.json` and `AGENTS.md` are listed in `_config.yml` `exclude:` so they are not copied into the published site.

### `release.yml` — Release

Si attiva sul push di un tag `v*` (e a mano con `workflow_dispatch`, passando un tag esistente). Il titolo della release è la **prima riga del tag annotato** (usare il solo nome del tag lo faceva comparire due volte, dato che la pagina mostra già il tag sotto al titolo). Crea la GitHub Release prendendo le note dalla sezione di `CHANGELOG.md` che corrisponde alla versione del tag (`v2.4.0` → `## [2.4.0]`); se quella sezione non c'è usa il messaggio del tag annotato, e in ultima istanza lascia generare le note a GitHub dai commit. Se la release esiste già ne aggiorna le note invece di fallire. Usa `gh` con il `GITHUB_TOKEN` del runner: nessuna action di terze parti, nessun secret.

**Quindi il flusso di rilascio è**: aggiorna `CHANGELOG.md` → `git tag -a vX.Y.Z` → `git push origin master --follow-tags`. La release compare da sola, e `jekyll.yml` (che ascolta anche i tag) ridistribuisce il sito.

### `failure-issue.yml` — Report workflow failure

Workflow **riusabile** (`workflow_call`): apre una issue etichettata `ci-failure` con il link al run fallito, o commenta quella già aperta per lo stesso workflow. È agganciato con `if: failure()` ai workflow schedulati (`youtube-sync`, `github-sync`, `robots-sync`, `strava-sync`, `uptime`), che girano di notte e senza nessuno che li guardi.

### `link-check.yml` — Link check

Cron il primo del mese (più `workflow_dispatch`): build del sito e html-proofer sui link **esterni**. I link morti finiscono in una issue `link-rot` (aggiornata, non duplicata) e il workflow **esce sempre verde**: un sito di terzi che sparisce non deve bloccare il deploy. I link *interni* restano un gate su ogni PR in `checks.yml`.

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
