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
- `_layouts/default.html` builds the `<head>` (Google Analytics when `analytics-google` is set, `jekyll-seo-tag`, favicon, RSS feed) and **inlines all CSS**: it captures `_includes/style.scss` and runs it through `scssify`. There is no separate CSS file in the output — to change styles, edit the partials in `_sass/` and they get picked up through `style.scss`.
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

## Directory map

| Path | Purpose |
|---|---|
| `_config.yml` | Site identity, social handles, plugins, feature toggles (see below). |
| `_posts/` | All content — blog posts and projects (see [Writing Content](writing-content.md)). |
| `_layouts/` | `compress` → `default` → `page` → `post` chain described above. |
| `_includes/` | Partials: `nav`, `footer`, `author`, `related`, `pagination`, `read-time`, `social-links`, `blog-post` (listing item), `youtube-facade` (lazy YouTube player, loaded on posts), `series` ("Part N of M" box), `giscus` (comments, inert until configured), `theme-init` (reads the saved theme in `<head>`, before first paint), `interactions` (image fade-in, view-transition naming, spotlight, counters, copy-code, theme toggle), `projects-filter`, analytics snippets, and `style.scss` (Sass entry point). |
| `_plugins/` | Custom build-time Ruby plugins (`lazy_images.rb`, `youtube_thumbnails.rb`, `toc.rb`). These **run** — see "Custom plugins" below. |
| `_sass/base/` | `tokens.scss` (**design tokens** + the two theme palettes, imported first), `variables.sass` (aliases Sass → token + breakpoints), `general`, `helpers`, `normalize`, `syntax` (maps Rouge classes to the `--syn-*` tokens; holds no colours of its own). |
| `assets/fonts/` | Self-hosted variable font (Inter, latin subset, 47 KB woff2), preloaded in `default.html`. |
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
| `analytics-google` | Google Analytics ID; the include is only rendered when set. |

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
