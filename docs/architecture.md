# Architecture

The site is a standard Jekyll 3.9 project based on the [Indigo theme](https://github.com/sergiokopplin/indigo), with the theme vendored directly into the repository (no gem-based theme), so every layout, include and stylesheet can be edited in place.

## Rendering pipeline

```
_posts/*.markdown ─┐
index.html         │    _layouts/post.html ─▶ _layouts/page.html ─▶ _layouts/default.html ─▶ _layouts/compress.html
blog/index.html    ├─▶  (Liquid + Markdown)                          │
projects.html      │                                                 ├─ inlines CSS: _includes/style.scss ─▶ _sass/**
tags.html          │                                                 └─ SEO tags, favicon, analytics, RSS
about.md          ─┘
```

- `_layouts/compress.html` minifies the final HTML at build time (pure Liquid, from [jekyll-compress-html](https://github.com/penibelst/jekyll-compress-html)).
- `_layouts/default.html` builds the `<head>` (`<meta charset>` first, then Google Analytics when `analytics-google` is set, `jekyll-seo-tag`, favicon, RSS feed) and **inlines all CSS**: it captures `_includes/style.scss` and runs it through `scssify`. There is no separate CSS file in the output — to change styles, edit the partials in `_sass/` and they get picked up through `style.scss`.
- `_layouts/default.html` renders the navigation (`_includes/nav.html`) **outside** the content wrapper and wraps the content in `<main id="content">`, the landmark the skip-link points to. The nav is a **floating glass island**: the sticky strip spans the viewport (so it can stick) but is `pointer-events: none`, and only the centred pill inside it is interactive — otherwise an invisible full-width bar would swallow clicks on the content scrolling underneath.
- The **home page is built in `index.html`**, not in `_includes/header.html`: an editorial opening (statement, metrics, curated sections, contact) rather than the theme's avatar hero. `header.html` now only renders the compact heading of Blog/Projects/Tags. Edit the opening copy in `index.html`.
- `_layouts/page.html` adds the hero/page header; `_layouts/post.html` wraps the article in `.post-article` (header, table-of-contents slot, `.post-content`), then prev/next navigation, related posts, author block, and (if configured) Disqus comments.

## Design system

Every colour, space, radius, duration and type step lives in **`_sass/base/tokens.scss`** as CSS custom properties on `:root`. The historical Sass variables (`$accent`, `$alpha`, …) still exist in `_sass/base/variables.sass` but are now thin aliases (`$accent: var(--color-accent)`) so the old partials keep working with a single source of truth. Practical consequences:

- **Re-theming means redefining tokens**, not editing every partial — that is exactly how the light theme below is built.
- Don't hard-code hex values in components — add or reuse a token.
- Sass colour functions (`darken()`, `rgba($var, …)`) **cannot** be applied to the palette variables anymore, because their value is a `var()` reference. Use a token with the opacity baked in instead (`--color-accent-soft`).
- `html` stays at `62.5%`, so **1rem = 10px** and the token scales follow that base (`--space-4: 1.6rem` = 16px).
- Type is fluid: `--text-*` steps use `clamp()`, so headings scale with the viewport without breakpoints. Post bodies are capped at `--measure` (68ch) for readability.
- Breakpoints (`variables.sass`): `$mobile` ≤ 560px, `$tablet` 561–1050px. The theme's original 560px `$mobile` was 400px, which left most phones (390–430 CSS px) on the tablet layout.
- **Listing cards** (`_sass/pages/home-blog-projects.sass`, shared by `/blog`, `/projects` and the home sections) stay horizontal on mobile — stacking them would put two posts on a screen — but the thumbnail is fluid (`clamp(100px, 30vw, 132px)`), and title and excerpt are clamped to two lines each so a long project slug can't take over the card. Two details worth knowing:
  - `:hover` is wrapped in `@media (hover: hover)`, with an `:active` state for touch. Without the guard the hover state sticks on a card after a tap on iOS.
  - YouTube thumbnails (`i.ytimg.com`, class `thumb-video` set by `_includes/blog-post.html`) are always served as a 480×360 frame with the black border baked into the pixels; there is no unpadded size to ask for. The image is scaled `1.3334` so that border falls outside the box, and on mobile the box becomes square, because half the channel is vertical Shorts and a 16:9 crop of those was mostly border.
- **Motion** lives in `_sass/components/motion.scss`, imported just before `polish.sass` so the `prefers-reduced-motion` block keeps the last word. Every effect is progressive enhancement: scroll-driven animations (`animation-timeline: view()/scroll()`) and view transitions sit inside `@supports`/`@media`, so an unsupporting browser shows the static v2.0.0 layout — never a half-animated or invisible element. Two practical rules learned the hard way:
  - **No `//` comments in inline `<script>`**: `_layouts/compress.html` collapses newlines, so everything after `//` on the collapsed line is commented out and the script dies silently. Use `/* … */`.
  - The `hidden` attribute needs `[hidden] { display: none !important }` in `general.sass`, otherwise a component's `display: block` overrides it (that's what made the projects filter "hide" cards that stayed on screen).
- The self-hosted variable font (Inter, latin subset, 47 KB) is declared in `_includes/style.scss` — not in a `_sass/` partial — because only that file is processed by Liquid and the `@font-face` URL needs `{{ site.baseurl }}`. `_layouts/default.html` preloads it.

## Themes (dark + light)

The site ships **two themes**. Dark is the default and the site's identity; light is a redefinition of the same token names, which is the payoff of putting the palette in custom properties in the first place.

`tokens.scss` declares two Sass mixins — `palette-dark` and `palette-light` — holding only the values that change with the theme: colours, `color-scheme`, shadows, the syntax-highlighting `--syn-*` set, and `--icon-sun`/`--icon-moon`. Everything theme-independent (spaces, radii, motion, type, layout) stays in `:root` and is declared once.

They are applied in this order, and **the order is what makes it correct** — not specificity, since `:root:not([data-theme="dark"])` and `:root[data-theme="light"]` weigh the same:

1. `:root` → `palette-dark`, the default.
2. `@media (prefers-color-scheme: light)` on `:root:not([data-theme="dark"])` → the system preference. The `:not()` is load-bearing: without it, a visitor whose OS is light but who explicitly picked dark would get light anyway, because this rule comes after `:root`.
3. `:root[data-theme="light"]` / `:root[data-theme="dark"]` → the explicit choice, last, so it beats both.

Rules when touching the palette:

- **Add every new colour to both mixins.** A token defined in only one theme silently stops changing with the theme, which is precisely how `strong` and `code` became invisible during v2.3. `scripts/check_contrast.rb` fails on this.
- **Overlays are not symmetric.** Dark lightens with white (`rgba(255,255,255,…)`), light darkens with black — hence the separate `--color-overlay-soft`, `--color-hover-overlay`, `--color-inset-line`, `--color-glass` tokens instead of raw rgba in components. Shadows follow the same rule: the dark theme's 45–60 % blacks read as smudges on a light background.
- **A mid-tone accent cannot serve both roles on light.** `--color-accent` is used both as text (26 places) and as a background with `--color-on-accent` on top (9 places). On a light background both readings improve as the green gets darker, so the light accent is a much deeper `#086830` rather than the dark theme's `#10cf53`.
- Two colours are deliberately *not* themed: the card placeholder monogram (white on its own gradient) and the play triangle over a video thumbnail. Both sit on their own surface, not on the page background.

Mechanics of the toggle:

- `_includes/theme-init.html` runs **in `<head>`, synchronously**, and copies the saved choice from `localStorage` onto `<html data-theme>`. It has to be there: the CSS default is dark, so anything later means a black flash for light-theme visitors on every page load.
- The button lives in `_includes/nav.html` and ships `hidden`; `_includes/interactions.html` reveals it, writes its `aria-label`, persists the choice, and collapses the two `theme-color` metas (which can't follow `data-theme`, only `prefers-color-scheme`) into a single one. **Without JavaScript there is no button at all** — the theme still follows `prefers-color-scheme`, so a dead control would be worse than none.
- Which icon shows is driven by the `--icon-sun`/`--icon-moon` tokens rather than by repeating the three-state selector logic in `nav.sass`.

Verify with **`ruby scripts/check_contrast.rb`** (stdlib only, no bundle): it parses the mixins straight out of `tokens.scss` — so it cannot drift from the real CSS — and checks 52 pairs across both themes against a 6:1 floor (`MIN=` to override). Lighthouse only ever audits the theme the page loads with, so this script is the only check that covers both.

## Responsive images

Local content images are served as WebP through a `<picture>` built at build time (#138). Two halves that stay independent on purpose:

- **`scripts/optimize_images.rb`** generates the variants and they are **committed**. It shells out to `cwebp`; nothing converts during the Jekyll build, because the `github-pages` bundle has no image encoders — same reasoning as the manually generated OG card.
- **`_plugins/responsive_images.rb`** wraps each `<img src="/assets/images/…">` in a `<picture>` with a `<source type="image/webp">`, **only when the variant files exist on disk**. Add an image without running the script and it is simply served unoptimized; nothing breaks.

Two formats are generated for every variant, AVIF first in the `<picture>` so browsers that support it never download the WebP. Numbers today: 158 WebP + 158 AVIF for the 67 images above the 150 KB threshold, +27 MB in the repo, and **−88 % on image bytes** across the 27 pages that carry local images (18.1 MB of originals → 4.0 MB as WebP → **2.1 MB as AVIF**).

Things that are the way they are for a measured reason:

- **Breakpoints are 480/960/1440** and the middle one must stay above ~900. The browser doesn't size against the CSS slot (~700px, the `--measure` cap) but against slot × DPR, so a phone asks for ~950–1080px. Replacing 960 with 720 was tried: Chrome jumps to the 1440 variant and the page grows from 0.9 MB to 1.3 MB.
- **No variant wider than 1440** is generated. With `sizes` capped at 700px even a DPR-2 screen never asks for more, so a native-width WebP of a 4000px source would be dead weight.
- **`<picture>` must not double-wrap.** The hook is registered on `[:posts, :pages, :documents]` and a post is both a `:post` and a `:document`, so it runs twice on the same output. The regex therefore matches `<picture>…</picture>` *before* `<img>`, so an already-wrapped image is consumed and returned untouched. (`lazy_images.rb` survives the same double run because of a negative lookahead on `loading=`.)
- **Card thumbnails are skipped** (`class` containing `thumb`): `home-blog-projects.sass` styles them with direct-child selectors (`> .thumb > img`) that an inserted `<picture>` would break. They are remote `i.ytimg.com` URLs anyway.
- **GIFs are skipped**: `error.gif` has 50 frames and `cwebp` only writes static WebP.
- **AVIF is encoded with `ffmpeg`, not `avifenc`.** `avifenc` cannot resize, so it could only ever have produced native-width AVIF — that is, almost never, since anything above 1440px is discarded. ffmpeg scales and encodes in one pass (`libaom-av1`, `-crf 32`, `-cpu-used 4`). Measured on a real photo at 960px: WebP q82 = 60 KB, AVIF = 32 KB at indistinguishable quality; `-cpu-used 4` is 2.5× faster than the default with a byte-identical result, and 6 starts costing size.
- **An AVIF set is dropped when it isn't smaller than the WebP one.** AVIF usually wins but not always, and the plugin puts it first — serving it would be a pessimisation. The comparison is over the whole set of widths, never a single variant: half an AVIF set would make the browser pick a lower width than it needs, which is just another way of making things worse.
- **Encoder output is validated, and a failed encode is retried once.** A crashed encoder still leaves its output file, empty — and since staleness was decided by `File.exist?`, that zero-byte file would have been treated as done forever and served inside the `srcset`. This is not hypothetical: 4 of 158 AVIF encodes failed transiently on the first batch, all 4 succeeded on a retry with identical parameters. A zero-byte file now counts as missing.

One honest caveat about Lighthouse on image-heavy posts: the performance score can *drop* after this change. Before, a 1 MB photo never finished painting inside the measurement window, so LCP fell back to the page title (~1.5 s); now the photo actually appears and becomes the LCP element (~5.5 s median on simulated mobile). The page delivers 4× fewer bytes — the metric just stopped flattering it. Individual posts are not in the Lighthouse CI url list, so no gate depends on this.

## Analytics

Off today: `analytics-google` is commented out in `_config.yml`, so `_includes/analytics-google.html` renders nothing and the site collects no data at all. The old Universal Analytics property stopped collecting in July 2023.

Turning it on is one line — create a GA4 property, add a web data stream for `https://allan-nava.github.io`, and paste the `G-XXXXXXXXXX` measurement ID into `analytics-google`. The steps are spelled out in the `_config.yml` comment.

The include is not the stock gtag snippet. It builds the `<script>` tag itself so it can decide **not** to, behind two guards:

- **Hostname** — nothing is sent from `localhost`, `127.0.0.1`, `0.0.0.0` or an empty host. Otherwise every `jekyll serve`, every Lighthouse CI run and every smoke test would land in the data as real traffic; on a site with modest numbers that noise would be a large share of the total.
- **Do Not Track / Global Privacy Control** — respected. It lowers the counts, and it is a deliberate choice: drop `trackingAllowed()` from the condition to disable it. Note this is *not* a consent banner; if one is ever needed, the place to hook a consent manager is right before the script is appended.

Measured before wiring it up, with a dummy ID: enabling GA4 leaves Lighthouse at **100 on all four categories** for the gated pages, so no CI gate is at risk. The two audits that do degrade (`uses-long-cache-ttl`, `unused-javascript`) are diagnostics with no weight in the score.

`<meta charset>` is emitted **before** the analytics include: the spec wants it as early as possible, and a `<script>` in front of it pushes it back for no benefit — the analytics script loads itself asynchronously and does not need to be first.

An `analytics-piwik.html` include also exists, unused and unreferenced by any config key.

## Social preview (og:image)

Every post gets a real preview image, resolved in this order:

1. its own `image:` (11 posts);
2. the YouTube thumbnail derived from the `<lite-youtube>` facade by `_plugins/youtube_thumbnails.rb` (123 posts);
3. a **per-post card with the title in it**, `assets/images/og/<post-filename>.jpg` (201 posts);
4. the generic `assets/images/og-default.png`, for anything else.

**The trap that made this necessary.** 315 of 335 posts carry `image: ""` in their front matter (that is what the sync scripts write). An empty string is **truthy** for `jekyll-seo-tag`, which resolved it as a relative URL and emitted `<meta property="og:image" content="https://allan-nava.github.io/">` — the site URL where an image should be. Those pages ended up with *two* `og:image` tags: the broken one from the SEO tag first, the correct fallback from `default.html` second. Scrapers read the first, so **201 project posts were being shared with a broken preview**.

`_plugins/og_image.rb` fixes it by deleting the empty key before rendering, which is enough because every template already tests `post.image and post.image != ""`. It runs as a Generator at `:lowest` priority, i.e. after `youtube_thumbnails.rb` (`:low`), so video posts keep their thumbnail and never get a card.

**The card goes in `page.og_card`, not `page.image`** — on purpose. `image` doubles as the listing thumbnail, so filling it would replace the generative monogram placeholders on `/blog`, `/projects` and the home page with 1200×630 social cards, downloading ~50 KB per row. `default.html` reads `og_card` only for the meta tags.

Cards are named after the **post filename, date included** — not the permalink slug, because three pairs of posts share a slug (`allan-nava-padel-murat4ll`, …) and would otherwise share one card carrying the wrong date. Cards are produced by **`ruby scripts/generate_og_cards.rb`** from `scripts/og_post_card.html` (Chrome screenshot at 1200×630, title and meta passed through the query string, font size stepped down by title length) and committed. They are **JPEG, not PNG**: 49 KB average instead of ~120 KB, which over 201 posts is the difference between 9.5 MB and 24 MB in the repo. The generator is idempotent and only touches posts that would otherwise have no preview of their own. `image-optimize.yml` runs it weekly so the project posts that `github-sync` creates hourly pick up a card; until then they fall back to the generic one, which is why nothing breaks if it never runs.

## PWA (installable + offline)

Three files at the repo root, all rendered by Jekyll so they can use Liquid:

- **`manifest.webmanifest`** — name, `standalone` display, theme/background `#050505`, four icons (192/512 in both `any` and `maskable`), plus shortcuts to Blog/Projects/Search. Linked from `default.html`.
- **`sw.js`** — the service worker. It has to sit at the **root**: a worker's scope can never rise above its own directory, so `/assets/sw.js` could not control `/blog/`.
- **`offline.html`** → `/offline/`, the fallback for a page never visited before.

Registration lives in `_includes/pwa.html`, deferred to the `load` event so it doesn't compete for bandwidth with the page the visitor is waiting for. If registration is refused (plain http, private mode, policy) the site behaves exactly as before.

The caching strategy is deliberately conservative, because a bad service worker on a live site serves stale content for a long time and cannot be fixed by deleting the file:

- **Freshness comes from the network, not from cache invalidation.** HTML is always **network-first**, so an edited post shows up on the first online load. Offline it falls back to the copy from the last visit, then to `/offline/`.
- **The cache name is not versioned per build.** The daily cron rebuild would otherwise wipe every visitor's offline cache once a day for nothing. Bump `CACHE` only when the *strategy* changes.
- Fonts, PWA icons and favicons are **cache-first** (immutable under a stable name). Everything else under `/assets/images/` is **stale-while-revalidate**, so an image replaced under the same filename fixes itself on the next visit rather than sticking forever.
- `search.json`, `feed.xml`, `sitemap.xml` and `robots.txt` are **never cached**: they are regenerated on every build, and a stale search index is worse than a network error.
- Cross-origin requests are left alone — YouTube thumbnails (`i.ytimg.com`) stay on the network and its own caching.

**To disable it**, deleting `sw.js` is not enough: browsers that already installed it keep using it. Replace the file's body with an unregister-and-clear worker (the recipe is in a comment at the top of `sw.js`) and deploy that.

Icons are generated from `scripts/pwa_icon.html` with **`ruby scripts/generate_pwa_icons.rb`** (Chrome screenshot at 512×512, then `sips`/ImageMagick down to 192) into `assets/images/pwa/` and committed — the same manual-step-plus-committed-PNG pattern as the OG card. The maskable variant shrinks the mark to ~62 %, because Android crops icons with a mask (often a circle) and would eat the corners of the full-bleed version.

Verified with a Node harness that loads the built `sw.js` into a sandbox with mocked service-worker globals and asserts the routing (22 checks: precache contents, old-cache cleanup, what is bypassed, network-first on HTML, offline fallbacks, stale-while-revalidate, cache-first fonts), plus a real-browser registration check through the DevTools protocol. Worth confirming once after the first deploy in DevTools → Application → Service Workers.

## Directory map

| Path | Purpose |
|---|---|
| `_config.yml` | Site identity, social handles, plugins, feature toggles (see below). |
| `_posts/` | All content — blog posts and projects (see [Writing Content](writing-content.md)). |
| `_layouts/` | `compress` → `default` → `page` → `post` chain described above. |
| `_includes/` | Partials: `nav`, `footer`, `author`, `related`, `pagination`, `read-time`, `social-links`, `blog-post` (listing item), `youtube-facade` (lazy YouTube player, loaded on posts), `series` ("Part N of M" box), `giscus` (comments, inert until configured), `theme-init` (reads the saved theme in `<head>`, before first paint), `pwa` (service-worker registration), `interactions` (image fade-in, view-transition naming, spotlight, counters, copy-code, theme toggle), `projects-filter`, analytics snippets, and `style.scss` (Sass entry point). |
| `_plugins/` | Custom build-time Ruby plugins (`lazy_images.rb`, `responsive_images.rb`, `og_image.rb`, `youtube_thumbnails.rb`, `toc.rb`). These **run** — see "Custom plugins" below. |
| `_sass/base/` | `tokens.scss` (**design tokens** + the two theme palettes, imported first), `variables.sass` (aliases Sass → token + breakpoints), `general`, `helpers`, `normalize`, `syntax` (maps Rouge classes to the `--syn-*` tokens; holds no colours of its own). |
| `assets/fonts/` | Self-hosted variable font (Inter, latin subset, 47 KB woff2), preloaded in `default.html`. |
| `manifest.webmanifest`, `sw.js`, `offline.html` | PWA: web app manifest, service worker (root scope, network-first HTML), offline fallback page — see "PWA". |
| `assets/images/og/` | Per-post social cards (`<post-filename>.jpg`, 1200×630) from `ruby scripts/generate_og_cards.rb`. |
| `assets/images/pwa/` | Installable-app icons (192/512, plus maskable) from `ruby scripts/generate_pwa_icons.rb`. |
| `assets/images/*.webp` | Responsive WebP variants (`name-480/960/1440.webp`) generated by `ruby scripts/optimize_images.rb` and committed. Served through `<picture>` — see "Responsive images". |
| `assets/images/og-default.png` | Social card used as `og:image` by every page without its own `image:`. Regenerate with `ruby scripts/generate_og_card.rb` after editing `scripts/og_card.html`. |
| `_sass/components/` | One file per UI component (header, nav, footer, author, pagination, side-by-side, spoiler, …). `polish.sass` is **imported last** and holds contrast fixes + hover/focus polish as cascade overrides — keep theme tweaks there rather than scattering them. |
| `_sass/pages/` | Page-specific styles (home/blog/projects listing, post, tags). |
| `index.html` | Home page (thin `page`-layout shell; content comes from config + includes). |
| `map.html` | `/map` — Leaflet map of every post with `lat`/`lng` front matter (toggle: `map` in `_config.yml`). |
| `fitness.html` | `/fitness` — workout PR tables + SVG charts from `_data/workouts.yml` (toggle: `fitness`). |
| `gear.md` | `/gear` — equipment list (toggle: `gear`). |
| `_data/workouts.yml` | Data source for `/fitness`. |
| `blog/index.html` | Blog listing; lives in its own folder to support Jekyll pagination if re-enabled. |
| `projects.html` | Projects listing; filters `site.posts` on `projects: true`, honours `externalLink` and `star`. |
| `tags.html` | Tag cloud + per-tag post lists, anchored by slugified tag name. |
| `about.md` | About page (`/about/`). |
| `archive.html` | `/archive/` — every post grouped by year (pure Liquid). |
| `stats.html` | `/stats/` — totals, posts per year, most used project tags; CSS bars, no JS. |
| `videos.html` | `/videos/` — grid of every post embedding a YouTube facade. |
| `search.html`, `search.json` | `/search/` — client-side search over the build-time index (194 entries, 44 KB). |
| `assets/images/`, `assets/video/` | Media; `.MOV` files tracked via Git LFS. |
| `404.html` | GitHub Pages custom 404. |

## Configuration (`_config.yml`)

Feature toggles read by layouts and includes:

| Key | Effect |
|---|---|
| `projects`, `about`, `blog` | Show/hide the corresponding nav entries and pages. |
| `read-time` | Show estimated reading time on posts. |
| `show-tags` | Show tag list under post titles. |
| `related` | Show "related posts" block after a post. |
| `post-advance-links` | Categories that get prev/next navigation (currently `[blog]`). |
| `show-author` | Show the author block after posts. |
| `animation` | Enable theme animations. |
| `width` | Content width: `normal` (`--width-normal`, 640px) or `large` (`--width-large`, 880px). |
| `name` | Signature printed by the templates (hero title, nav brand, footer). Distinct from `title`; when it was missing those strings rendered empty. |
| `paginate`, `paginate_path` | Blog pagination — currently commented out, so `/blog` lists everything. |
| `analytics-google` | GA4 measurement ID (`G-XXXXXXXXXX`). Commented out today, so nothing is collected; the include only renders when it is set. See "Analytics". |

Social handles (`github`, `instagram`, `linkedin`, `youtube`, `twitter`, `dev`) feed `_includes/social-links.html`. The `authors:` map defines the author block data; post `author` fields must reference a key in it.

## Plugins

Declared in `_config.yml` and provided by the `github-pages` gem (all whitelisted by GitHub Pages):

- `jekyll-seo-tag` — meta/OpenGraph tags via `{% seo %}` in `default.html`
- `jekyll-feed` — RSS at `/feed.xml`
- `jekyll-sitemap` — `/sitemap.xml` (350+ URLs). **It also generates a `robots.txt` containing the `Sitemap:` line — but only when the repo has none** (`@site.pages << robots unless file_exists?("robots.txt")`). This repo ships its own `robots.txt`, so that automatic declaration never happened and the host advertised no sitemap at all until it was added. `robots.txt` is now a **Liquid template** (it carries empty front matter so Jekyll renders it): it prints the fixed host `Sitemap:` line plus one line per entry in `_data/pages_sitemaps.yml`. Crawlers read `robots.txt` only from the host root, so this one file speaks for every project site under `allan-nava.github.io/<repo>/` too — hence one `Sitemap:` per site. That data file is **generated in CI** by `scripts/sync_robots_sitemaps.rb` (workflow `robots-sync.yml`, config `_data/robots_sync.yml`): it lists only `Allan-Nava`-owned Pages sites whose `sitemap.xml` returns 200, so nothing is declared that isn't actually served. See `docs/deployment.md` for the workflow.
- `jemoji` — `:emoji:` shortcodes
- `jekyll-gist` — GitHub gist embeds

- `jekyll-paginate` — paginates `/blog` (`paginate: 10`); see "Pagination" below.

`jekyll-admin` (local-only) adds the `/admin` UI when serving locally; it plays no role in production builds.

## Custom plugins (`_plugins/`)

Unlike a site built on GitHub's own Pages infrastructure (which runs Jekyll in `--safe` mode and ignores `_plugins/`), this site is built with a full `bundle exec jekyll build` inside GitHub Actions (see [Deployment & CI](deployment.md)). **Custom plugins in `_plugins/` therefore execute** at build time — both in CI and locally.

- `lazy_images.rb` — a `:post_render` hook that adds `loading="lazy"` + async decoding to content `<img>` tags. kramdown can't set a global image attribute, so Markdown photos would otherwise load eagerly. It skips images that already declare a `loading` attribute and the above-the-fold hero images (`title-image`, `selfie`), which stay eager as LCP candidates.
- `youtube_thumbnails.rb` — a `Generator` that fills an empty `image:` with `https://i.ytimg.com/vi/<id>/hqdefault.jpg` when the post body contains a `<lite-youtube videoid="…">` facade (114 posts today). The backfilled video posts predate the thumbnail feature, so without it the listing cards and `og:image` would be empty. It only touches in-memory document data — nothing is written back to `_posts/`.
- `card_placeholder.rb` — two Liquid filters (`card_initials`, `card_palette`) used by the listing cards to draw a monogram on a gradient when a post has no `image:`. The palette index comes from a stable hash of the title (not Ruby's `Object#hash`, which is randomised per process), so a project keeps the same colour across builds.
- `project_tags.rb` — a `Generator` that fills `site.data.project_tags` with the 12 most used tags among project posts, for the `/projects` filter chips. Counting is **per slug and per post**, which is what makes the number on a chip equal the number of cards left after filtering (Liquid can't sort a map by value, hence the plugin).
- `toc.rb` — replaces the `<div class="toc-slot"></div>` emitted by `_layouts/post.html` with a collapsible `<details>` index of the post's `h2`/`h3`, or removes it when the post has fewer than 3 headings (which is every post today — the feature kicks in for long-form articles). It reads the ids kramdown already generates, so it needs no HTML parser.

## Pagination

`/blog` is paginated with `jekyll-paginate` (v1, bundled with `github-pages`): `paginate: 10` + `paginate_path: "blog/:num/"`, rendered by `_includes/pagination.html`. `blog/index.html` must stay named `index.html` in its own folder for the paginator to run. **Caveat:** v1 paginates *all* `_posts` (including `hidden: true` projects); `blog/index.html` filters those out, so the oldest pages (2019-era projects) render fewer than 10 items while recent pages are full. v2 (per-category pagination) is not whitelisted by GitHub Pages, so this is the ceiling with the stock gem.

## YouTube embeds (facade)

Video embeds use a lightweight facade instead of a raw `<iframe>`: posts contain `<lite-youtube videoid="…">` elements, and `_includes/youtube-facade.html` (self-contained CSS + a small custom element, no CDN) renders a clickable thumbnail, loading the real cookie-less player (`youtube-nocookie.com`) only on click. This is the biggest per-page win now that most posts embed video. The sync scripts emit this markup directly; `scripts/migrate_youtube_embeds.rb` converted the existing posts (see [Writing Content](writing-content.md)).

## Dependency automation

**Dependabot** (`.github/dependabot.yml`) opens weekly PRs for Ruby gems (`bundler`) and GitHub Actions versions.
