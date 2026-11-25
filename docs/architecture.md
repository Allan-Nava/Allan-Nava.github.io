# Architecture

The site is a standard Jekyll 3.9 project based on the [Indigo theme](https://github.com/sergiokopplin/indigo), with the theme vendored directly into the repository (no gem-based theme), so every layout, include and stylesheet can be edited in place.

## Rendering pipeline

```
_posts/*.markdown ─┐
index.html         │    _layouts/post.html ─▶ _layouts/page.html ─▶ _layouts/default.html ─▶ _layouts/compress.html
blog/index.html    ├─▶  (Liquid + Markdown)                          │
projects.html      │                                                 ├─ <link> to /assets/css/main-<hash>.css (_plugins/site_css.rb ◀ _includes/style.scss ◀ _sass/**)
tags.html          │                                                 └─ SEO tags, favicon, analytics, RSS
about.md          ─┘
```

- `_layouts/compress.html` minifies the final HTML at build time (pure Liquid, from [jekyll-compress-html](https://github.com/penibelst/jekyll-compress-html)).
- `_layouts/default.html` builds the `<head>` (`<meta charset>` first, then Google Analytics when `analytics-google` is set, `jekyll-seo-tag`, favicon, RSS feed) and **links one stylesheet**, `site.css_path`. `_plugins/site_css.rb` builds it once per build: it renders `_includes/style.scss` through Liquid (for the `{{ site.baseurl }}` of the `@font-face`), compiles it with the same Sass converter `scssify` used, compressed (`sass.style` in `_config.yml`), and writes `assets/css/main-<hash>.css`, the first 10 hex of the SHA-256 of the CSS. The name changes only when the CSS does, not on every build (the site rebuilds hourly for the syncs), so a browser and the service worker keep it as immutable. Until #181 the whole stylesheet was **inlined** in a `<style>` in every page: 106 KB of the 148 KB of `/about/`, never cached, and one Sass compilation per page. To change styles, edit the partials in `_sass/`; they are picked up through `style.scss`.
- `_layouts/default.html` renders the navigation (`_includes/nav.html`) **outside** the content wrapper and wraps the content in `<main id="content">`, the landmark the skip-link points to. The nav is a **floating glass island**: the sticky strip spans the viewport (so it can stick) but is `pointer-events: none`, and only the centred pill inside it is interactive — otherwise an invisible full-width bar would swallow clicks on the content scrolling underneath. The pill ends with two icon buttons sharing one style block in `nav.sass`: the **search** link (an `<a>` to `/search/`, so it works without JavaScript — it used to live only in the footer, #156) and the **theme toggle** (a `<button>`, `hidden` until JS shows it, since without JS there is nothing to toggle).
- The **home page is built in `index.html`**, not in `_includes/header.html`: an editorial opening (statement, metrics, curated sections, contact) rather than the theme's avatar hero. Edit the opening copy in `index.html`.
- `_includes/header.html` renders the `<h1>` of **every** page that goes through `_layouts/page.html` except the home, plus the optional `subtitle:` from the front matter; `custom_header: true` opts a page out (only `404.html` needs it). It used to fire on a hard-coded list of four titles while four other pages hand-rolled their own header, which left five pages — `/about`, `/map`, `/fitness`, `/gear`, `/offline` — with no `<h1>` at all (#150). The `showHeader` variable still assigned there is **not** about the title any more: `default.html` reads it to pick the content wrapper class (`.blog` instead of `.page blog`), so changing that list changes the CSS of those pages.
- `_layouts/page.html` adds the hero/page header; `_layouts/post.html` wraps the article in `.post-article` (header, table-of-contents slot, `.post-content`), then prev/next navigation, related posts, author block, and (if configured) Disqus comments.

## Design system

Every colour, space, radius, duration and type step is a CSS custom property on `:root`, and the values come from **[nava-ui](https://github.com/Allan-Nava/nava-ui)**, the UI kit extracted from this site. `_sass/vendor/_nava-tokens.scss` is the kit's `dist/tokens.site.scss` of a pinned release: the kit's tokens already in this site's dialect — `--color-*` names, the 10px rem, and three mixins, `palette-dark`, `palette-light` and `scale`. `scripts/sync_nava_ui.sh vX.Y.Z` replaces the copy with another release, and `checks.yml` runs `scripts/sync_nava_ui.sh --check`, which fails if the copy is not byte for byte the file of the tag named in its first line. **So a colour is changed in the kit** — where its contrast pairs and screenshots are checked — released, and pinned here. `_sass/base/tokens.scss` keeps only what belongs to the site: the tokens no kit component uses (the 17 `--syn-*` syntax colours and `--color-inset-line-strong`, in `site-palette-dark`/`site-palette-light`) and the order the palettes are applied in. The switch, on 2026-11-15, was compiled before and after: every declaration came out with the same value; the kit only added its own new tokens (`--color-danger`, `--color-info`, `--color-warning`, `--color-success`, `--color-border-control`). The kit's `nv-aliases` mixin is included on `:root`: it points the kit's `--nv-*` names at the site's, so the kit's components read the site's values, theme included. **Components come from the kit too**, one partial per component (`dist/site/_nava-<section>.scss` of the same release, with the 10px rem already applied and no comments), listed in `PARTS` in `scripts/sync_nava_ui.sh` and imported one by one in `_includes/style.scss` — only the ones the site uses, because every page loads the whole stylesheet. Today: the bento grid and the marked pills, for `/stack/` and "What I work with"; the banner, for `/videos/`; the bar list, for `/stats/`; the profile and the award, for `/about/`; the code block with a copy button (`nv-code`, since v0.10.0), for the code blocks of the posts: `_includes/interactions.html` adds the `nv-code` class to each Rouge block and appends the `nv-code__copy` button and a hidden `role="status"` that announces the copy. The historical Sass variables (`$accent`, `$alpha`, …) still exist in `_sass/base/variables.sass` but are now thin aliases (`$accent: var(--color-accent)`) so the old partials keep working with a single source of truth. Practical consequences:

- **Re-theming means redefining tokens**, not editing every partial — that is exactly how the light theme below is built.
- Don't hard-code hex values in components — add or reuse a token.
- Sass colour functions (`darken()`, `rgba($var, …)`) **cannot** be applied to the palette variables anymore, because their value is a `var()` reference. Use a token with the opacity baked in instead (`--color-accent-soft`).
- `html` stays at `62.5%`, so **1rem = 10px** and the token scales follow that base (`--space-4: 1.6rem` = 16px).
- Type is fluid: `--text-*` steps use `clamp()`, so headings scale with the viewport without breakpoints. Post bodies are capped at `--measure` (68ch) for readability.
- Breakpoints (`variables.sass`): `$mobile` ≤ 560px, `$tablet` 561–1050px. The theme's original 560px `$mobile` was 400px, which left most phones (390–430 CSS px) on the tablet layout.
- **Listing cards** (`_sass/pages/home-blog-projects.sass`, shared by `/blog`, `/projects` and the home sections) stay horizontal on mobile — stacking them would put two posts on a screen — but the thumbnail is fluid (`clamp(100px, 30vw, 132px)`), and title and excerpt are clamped to two lines each so a long project slug can't take over the card. Two details worth knowing:
  - `:hover` is wrapped in `@media (hover: hover)`, with an `:active` state for touch. Without the guard the hover state sticks on a card after a tap on iOS.
  - **Project thumbnails normalise the container, not the image** (#151, class `thumb-project` on the `.thumb` span in `projects.html` and the home "Recent projects" section). The images come from other repos' READMEs and have nothing in common — measured on the 17 that exist: 6 logos carrying their own background inside the file, 4 diagrams on white, 3 dark screenshots and one light chart on transparency. On the dark theme the white ones were glaring rectangles between the monogram gradients. The fix is entirely in the container: `object-fit: contain` with `--space-2` of padding so every tile has the same shape whatever the source ratio, a neutral `--color-thumb-bg` tile visible around the image and under transparency, an inset hairline, and a `--color-thumb-veil` pseudo-element on top that damps white backgrounds on dark (zero on light, where a logo on white already belongs). The files themselves are never filtered — they change without notice, and `cover` stays for blog and video thumbnails, whose sources are photos and YouTube frames that should fill the box.
  - **YouTube thumbnails** (`i.ytimg.com`) come in two shapes, and the difference is measured, not guessed (#163). `hqdefault.jpg` is *always* 480×360: for a 16:9 video it holds the frame in the middle 270px between two 45px black bars; for a vertical video it holds the frame in the centre with YouTube's own blurred copy filling the sides. Two consequences:
    - **16:9 sources** keep `image:`/`hqdefault` and the `thumb-video` class. In the 16:9 desktop box `object-fit: cover` crops exactly those 45px bars, so **no zoom is needed** — the old blanket `transform: scale(1.3334)` was a 33% over-crop there. In the **square** mobile box, cover crops the width instead and the bars survive, so that is the one place the `4/3` zoom belongs.
    - **Vertical sources** (74 of 133 videos) carry `thumb:` = `oardefault.jpg`, the original-ratio 1080×1920 frame, plus the `thumb-short` class, and get a portrait box: square in the compact listing, `3/4` on `/videos`, which is why that grid is deliberately ragged (`align-items: start`). A 9:16 image in a 16:9 box is a horizontal sliver of a vertical video. `oardefault.jpg` exists **only** when the original ratio isn't 16:9 and 404s otherwise, so its presence *is* the orientation signal — more reliable than the `short` tag, which is wrong in 4 of 133 cases.
- **Motion** lives in `_sass/components/motion.scss`, imported just before `polish.sass` so the `prefers-reduced-motion` block keeps the last word. Every effect is progressive enhancement: scroll-driven animations (`animation-timeline: view()/scroll()`) and view transitions sit inside `@supports`/`@media`, so an unsupporting browser shows the static v2.0.0 layout — never a half-animated or invisible element. Two practical rules learned the hard way:
  - **No `//` comments in inline `<script>`**: `_layouts/compress.html` collapses newlines, so everything after `//` on the collapsed line is commented out and the script dies silently. Use `/* … */`.
  - The `hidden` attribute needs `[hidden] { display: none !important }` in `general.sass`, otherwise a component's `display: block` overrides it (that's what made the projects filter "hide" cards that stayed on screen).
  - **`jemoji` rewrites the inside of `<script>` too.** It runs after Liquid on the finished HTML and only skips `pre`/`code`/`tt` — the pipeline is hardcoded in the gem, there is no way to add `script`. One shortcode anywhere on the page (ten posts carry one in their title) is enough for two failures: the shortcode inside a JS string becomes `<img class="emoji" …>` whose double quotes end the string (*Unexpected identifier*, dead page), and jemoji reparses and reserialises the **whole** document with Nokogiri, which mistakes HTML strings inside the JS for markup and rewrites their attributes (`'<a href="' + s.url` became `'<a href="'%20+%20s.url`). This killed `/map`. The fixes there: titles are emitted with `| replace: ":", "\u003a"` — still `:` in JS, but no longer a match, so the document is never reparsed — and popups are built with DOM calls instead of concatenated HTML.
- The self-hosted variable font (Inter, latin subset, 47 KB) is declared in `_includes/style.scss` — not in a `_sass/` partial — because only that file is processed by Liquid and the `@font-face` URL needs `{{ site.baseurl }}`. `_layouts/default.html` preloads it.

## Themes (dark + light)

The site ships **two themes**. Dark is the default and the site's identity; light is a redefinition of the same token names, which is the payoff of putting the palette in custom properties in the first place.

Two pairs of Sass mixins hold the values that change with the theme: `palette-dark`/`palette-light` from the kit (colours, `color-scheme`, shadows, `--icon-sun`/`--icon-moon`), and `site-palette-dark`/`site-palette-light` in `tokens.scss` (the `--syn-*` set and `--color-inset-line-strong`). Everything theme-independent (spaces, radii, motion, type, layout) is the kit's `scale` mixin, included once in `:root`.

They are applied in this order, and **the order is what makes it correct** — not specificity, since `:root:not([data-theme="dark"])` and `:root[data-theme="light"]` weigh the same:

1. `:root` → `palette-dark`, the default.
2. `@media (prefers-color-scheme: light)` on `:root:not([data-theme="dark"])` → the system preference. The `:not()` is load-bearing: without it, a visitor whose OS is light but who explicitly picked dark would get light anyway, because this rule comes after `:root`.
3. `:root[data-theme="light"]` / `:root[data-theme="dark"]` → the explicit choice, last, so it beats both.

Rules when touching the palette:

- **Add every new colour to both mixins.** A token defined in only one theme silently stops changing with the theme, which is precisely how `strong` and `code` became invisible during v2.3. `scripts/check_contrast.rb` fails on this. A colour the kit's components could use belongs in the kit; only a site-only one is added here, to both `site-palette-*` mixins.
- **Overlays are not symmetric.** Dark lightens with white (`rgba(255,255,255,…)`), light darkens with black — hence the separate `--color-overlay-soft`, `--color-hover-overlay`, `--color-inset-line`, `--color-glass` tokens instead of raw rgba in components. Shadows follow the same rule: the dark theme's 45–60 % blacks read as smudges on a light background.
- **A mid-tone accent cannot serve both roles on light.** `--color-accent` is used both as text (26 places) and as a background with `--color-on-accent` on top (9 places). On a light background both readings improve as the green gets darker, so the light accent is a much deeper `#086830` rather than the dark theme's `#10cf53`.
- Two colours are deliberately *not* themed: the card placeholder monogram (white on its own gradient) and the play triangle over a video thumbnail. Both sit on their own surface, not on the page background.

Mechanics of the toggle:

- `_includes/theme-init.html` runs **in `<head>`, synchronously**, and copies the saved choice from `localStorage` onto `<html data-theme>`. It has to be there: the CSS default is dark, so anything later means a black flash for light-theme visitors on every page load.
- The button lives in `_includes/nav.html` and ships `hidden`; `_includes/interactions.html` reveals it, writes its `aria-label`, persists the choice, and collapses the two `theme-color` metas (which can't follow `data-theme`, only `prefers-color-scheme`) into a single one. **Without JavaScript there is no button at all** — the theme still follows `prefers-color-scheme`, so a dead control would be worse than none.
- Which icon shows is driven by the `--icon-sun`/`--icon-moon` tokens rather than by repeating the three-state selector logic in `nav.sass`.

Verify with **`ruby scripts/check_contrast.rb`** (stdlib only, no bundle): it parses the mixins straight out of the kit's copy and `tokens.scss`, merging the two mixins of each theme — so it cannot drift from the real CSS — and checks 52 pairs across both themes against a 6:1 floor (`MIN=` to override). Lighthouse only ever audits the theme the page loads with, so this script is the only check that covers both.

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

## Comments (giscus)

Live on posts only, backed by GitHub Discussions in the **Announcements** category — not answerable, and only maintainers can open threads there, so the discussions are created by the giscus app on the first comment.

The two ids in `_config.yml` are **not** copied from giscus.app: they are GraphQL node ids and can be read straight from the API, which is also how to recover them if they are ever lost:

```bash
gh api repos/:owner/:repo --jq .node_id                     # repo-id
gh api graphql -f query='{repository(owner:"Allan-Nava",name:"Allan-Nava.github.io"){discussionCategories(first:20){nodes{id name}}}}'
```

To check the app is actually installed on a repo — enabling Discussions is not the same thing — ask giscus itself: `https://giscus.app/api/discussions?repo=OWNER/REPO&term=/x/&category=<id>` answers `Discussion not found` (404) when everything is wired and simply nobody has commented yet, versus `giscus is not installed on this repository` (403) when the app is missing.

`_includes/giscus.html` builds the `<script>` tag in JS rather than emitting it statically, because **the widget has to follow the site's two themes**. `data-theme` must be right before the iframe is created, otherwise a light-mode reader gets a dark comment box and then a jump; once the iframe exists the theme can only be changed by `postMessage`, which is what the `MutationObserver` on `data-theme` does. giscus's own `preferred_color_scheme` is not usable here: it follows the OS and would ignore an explicit choice made with the site toggle. The include still renders nothing while `repo-id` or `category-id` are empty.

## Webmentions

Likes, reposts and replies from Mastodon and Bluesky, collected under each post (#133). Three moving parts:

- `_includes/webmention-links.html` — the `rel="webmention"` and `rel="pingback"` links, in the `<head>` of **every** page, not just posts: a sender looks for them on whatever page it is linking to. `pingback` is webmention.io's bridge for senders still speaking the older protocol, not a duplicate.
- `_includes/webmentions.html` — the section itself: a facepile for likes/reposts and a list for replies, fetched from `webmention.io/api/mentions.jf2` at page load.
- `_sass/components/webmentions.scss` — the styles, tokens only, so both themes are covered.

**All of it is off while `webmentions.domain` is empty in `_config.yml`** — no `<link>`, no section. A page that advertises an endpoint for an unregistered domain sends every sender to a 404, which is worse than advertising nothing.

The content is written by strangers, so it is treated as hostile input: every string enters the DOM through `textContent` and every element through `createElement` (never `innerHTML`, never string-concatenated HTML), the reply body is read from `content.text` and never `content.html`, and every URL goes through a scheme check — a `javascript:` URL in a profile link would otherwise run on click. Building the DOM instead of concatenating strings also sidesteps jemoji, which re-parses the whole document as soon as it finds a `:shortcode:` and mangles HTML strings sitting inside JS.

Two things have to be done by hand, outside this repo: register the domain on [webmention.io](https://webmention.io) (GitHub login), and connect the Mastodon/Bluesky accounts on [brid.gy](https://brid.gy) so interactions are forwarded. Until both are done, filling in `domain` only publishes an endpoint nobody sends to.

## Analytics

**On since August 2026**: `analytics-google` is set to `G-X841VQSHB8` in `_config.yml` — GA4 property "Allan Nava github pages - GA4", web data stream `5725926646`. The old Universal Analytics property (`UA-132362885-1`) stopped collecting in July 2023 and is dead.

Turning it off is one line too: comment `analytics-google` out again and `_includes/analytics-google.html` renders nothing, because the include only fires when the key has a value.

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

## Search engines (titles, descriptions, identity)

`jekyll-seo-tag` renders inside `default.html`, but two of its outputs are overridden there — deliberately.

**The `<title>` is composed by `default.html`, not by the plugin** (`{% seo title=false %}` suppresses the plugin's). The plugin's rule is `"{page.title} | {site.title}"`, and the home page's `title:` is what the nav and the wrapper class key on — so the home shipped to Google as **`Home | Allan Nava`**. The first word of a title is the one that carries the most weight, and it was saying nothing. The composition order in `default.html` is:

1. `seo_title:` in the page front matter, when a page wants an exact title;
2. the home page (`page.url == "/"`) → `"{site.name} — {site.tagline}"`;
3. a paginated listing → `"{page.title} — page N | {site.title}"` (distinct titles, so `/blog/2/` isn't seen as a duplicate of `/blog/`);
4. any other page → `"{page.title} | {site.title}"`.

**The home page's `title:` is `Allan Nava`, not `Home`.** `og:title` is the one field with no override in `jekyll-seo-tag` — it reads `page.title` and nothing else — so every share of the home page on LinkedIn or WhatsApp was titled "Home". Renaming it meant unhooking the two things that keyed on the string: `_includes/header.html` now tests `page.url == "/"`, and the wrapper class in `default.html` uses `slugify` instead of `downcase` so a title with a space doesn't emit two classes.

**One description, one canonical.** The theme printed its own `<meta name=description>` from `site.bio` on top of the plugin's, and `default.html` printed a second `<link rel=canonical>` on top of the plugin's. Both duplicates are gone: with two descriptions a search engine picks one (usually the first, i.e. the generic one), and two canonicals are a contradictory signal that can get both ignored. `site.description` in `_config.yml` is now filled — it is the fallback for every page that declares no `description:` of its own, and it was an empty string, which is why the whole site advertised nothing but the theme's bio.

**Every post is signed "Allan Nava".** `jekyll-seo-tag` resolves `author: allan` through `_data/authors.yml` only — not through `authors:` in `_config.yml`, which the author box under a post reads. Until 2026-11-19 that file did not exist, so all ~440 posts said `<meta name="author" content="allan">` and `"author": {"@type": "Person", "name": "allan"}` in their `BlogPosting`: nothing tied a post to the person the home page is about. `_data/authors.yml` now gives the name and the `/about/` URL, and the two files keep the same name.

**Video posts get a generated description (#185).** 134 posts are YouTube videos with `description: ""` and, for 133 of them, no text at all, so they all fell back to `site.description`. `_plugins/video_descriptions.rb` composes one at build time from the title, the author, the publication date and whether the video is vertical (`thumb:` = `oardefault.jpg`): "Dips 55kg: a short video Allan Nava published on YouTube on 9 January 2025." It is not the v2.7 boilerplate (#162), which only repeated the title. Tags are left out: on these posts they are only `youtube` plus `short` or `video`. The files are not touched, so future synced videos get one too. The post is marked `description_generated: true` and the listing cards (`index.html`, `projects.html`, `_includes/blog-post.html`) skip it, because there one sentence repeated on every card is noise; the meta tags, JSON-LD, feeds and search use it.

**Markdown twins (#192).** Every post also exists as Markdown at its URL with `.md` for `.html`, written by `_plugins/markdown_twins.rb` in a `:site, :post_write` hook straight into `_site` (a `.md` page handed to Jekyll would be converted to HTML): a reduced front matter (title, date, description, canonical, lang), the title as an H1, then the post's source with `{% post_url %}` and `{{ site.url }}` resolved, other Liquid and HTML comments dropped, and the YouTube facade turned into a link. `_layouts/default.html` links it with `<link rel="alternate" type="text/markdown">` and `/llms.txt` lists the twins. They are not in the sitemap: they are alternates of URLs that are.

**Page dates and listing thumbnails (#188, #187).** `_plugins/page_lastmod.rb` sets each page's `last_modified_at` from the newest commit that touched its file (one `git log --name-only` over the history, skipped on a shallow clone, hence `fetch-depth: 0` in `jekyll.yml`), so `sitemap.xml` carries a `<lastmod>` for pages and `scripts/indexnow.rb diff` sees a changed page. Generated pages (pagination, tags) have no file and no date; a page's date is its file's, so `/map/` changes when `map.html` does, not when a post adds a marker. The listing cards of vertical videos use `thumb_small`, a 270px WebP copy of YouTube's 1080x1920 `oardefault.jpg` that `scripts/cache_short_thumbs.rb` writes to `assets/images/thumbs/` (weekly in `image-optimize.yml`, with `cwebp`) and `_plugins/short_thumbs.rb` assigns when the file exists; a Short newer than the last run keeps the YouTube URL. The first four cards of a listing load eagerly, the first with `fetchpriority="high"`. `/videos/` keeps the originals, whose slots are up to 363px wide.

**Language of a post (#194).** `<html lang>` comes from `page.lang` (default `en`) and `og:locale` from `locale`. Until #194 only four posts declared `it`, so most of the Italian ones said `en`. `scripts/lib/post_language.rb` tells the two languages apart by a stopword count over title, description and body (HTML, Liquid, URLs and code removed): at least five hits and 65% for one side, or, for a line or two, two hits and none of the other; words both languages use (`a`, `in`, `me`, `come`, `ai`) count for neither, and a text too short to tell returns nothing and keeps the default. `scripts/set_post_language.rb` (one-shot, `DRY_RUN=1` to list) added `lang: it` and `locale: it_IT` to 87 posts (127 read as English, 186 too short). `sync_youtube.rb` and `sync_github.rb` pass every post they write through `PostLanguage.with_lang`, so a new post and a refreshed one are judged the same way; `sync_strava.rb` writes `lang: it` because its template is Italian. `validate_posts.rb` warns when a post's `lang` disagrees with its text.

**Crawl fixes and the SEO audit (2026-11-25).** A crawl of the 440 sitemap URLs found the basics clean (a title, description, canonical and og:image everywhere, one `<h1>` per page) and three quality problems, fixed at build time by `_plugins/seo.rb` without touching the posts: 13 posts sharing a title with another get the date in their `<title>` (`seo_title`); 76 project posts whose description was the repository's one-liner, often just its name, get a sentence that says what and whose it is (`HelloWorldSwift: an open-source Swift project by Allan Nava on GitHub (Allan-Nava/HelloWorldSwift).`), while the listing cards keep the original through `card_description`; the 23 paginated `/blog/` pages, which shared one description, say "Page N of M". Video posts carry a `VideoObject` JSON-LD (`_includes/schema-video.html`, from the `video_id` the plugin sets), which Google's video results need; its values go through `replace: ":", "\u003a"` for the jemoji reason above. `scripts/seo_audit.rb` runs in `checks.yml` on the built `_site`: it fails on a page of the sitemap without a title, description, canonical equal to its URL, og:image, exactly one `<h1>`, or with JSON-LD that does not parse, and warns (job summary) on duplicate titles and descriptions. Since #193 it also fails on a title over 70 characters or a description under 50: the plugin gives the 18 long titles, nearly all videos, a `seo_title` without emoji and hashtags (a run of emoji between words becomes " · ", then trailing segments and words go until it fits; the heading keeps the full title), and the 38 short descriptions a sentence of what, whose, when and tags (`Banksy: a post by Allan Nava, January 2022 (banksy, art).`), the cards keeping the original. There is no GitHub Action that makes Google index faster: Google's Indexing API is only for job postings and livestreams; for Google the sitemap and Search Console are the way, for Bing and DuckDuckGo IndexNow.

**IndexNow.** DuckDuckGo answers from Bing's index, and Bing (with Yandex and the other engines of the protocol) takes pushed URLs through IndexNow. The deploy workflow saves the live `sitemap.xml` before the build, `scripts/indexnow.rb diff` keeps the URLs that are new or whose `<lastmod>` changed, and an `indexnow` job submits them once the deploy is live. The key is the public file `<32 hex>.txt` at the repo root, served at the site root. A manual run with `indexnow_all` submits the whole sitemap (for the first submission, or after URLs change). Google is not part of IndexNow: there the sitemap and Search Console stay the way.

**Identity (`sameAs` + `rel="me"`).** For a query that is a person's name, a search engine has to be able to tie the domain to the person. `_includes/schema-person.html` emits a JSON-LD `@graph` with a `Person` (name, image, job, employer, city, `sameAs`) and a `WebSite` that names the Person as its author and publisher; it is included **only on `/` and `/about/`**, the two pages that are about the person. The profile URLs are not hard-coded there — they come from `social.links` in `_config.yml`, and the same profiles are linked with `rel="me"` from `_includes/social-links.html`.

That is the half of the job that lives in the repo. **The other half does not**: the link back *from* each profile to `https://allan-nava.github.io/` (GitHub's "Website" field, the LinkedIn contact info, the YouTube channel's About tab) has to be set on those sites. As of writing, the GitHub profile's website field points at LinkedIn, not at this site.

> The JSON-LD is written with **a space after every colon** on purpose. `jemoji` also runs inside `<script>` tags, and a single `:word:` sequence in the document makes it re-parse and rewrite the whole HTML (see the `/map` incident in `CLAUDE.md`). A space after the colon means no shortcode pattern can ever match.

**Search Console.** `google_site_verification` in `_config.yml` holds the token of the `https://allan-nava.github.io/` URL-prefix property; `jekyll-seo-tag` turns it into `<meta name="google-site-verification">` on **every** page (387 of them), which is why the layout must never print one by hand. Only the `content` value belongs in the config, not the whole tag.

**Do not delete the token once the property is verified.** Google re-checks the tag periodically: if it disappears the property reverts to unverified, taking with it the index coverage data and the ability to request indexing of a URL.

## PWA (installable + offline)

Three files at the repo root, all rendered by Jekyll so they can use Liquid:

- **`manifest.webmanifest`** — name, `standalone` display, theme/background `#050505`, four icons (192/512 in both `any` and `maskable`), plus shortcuts to Blog/Projects/Search. Linked from `default.html`.
- **`sw.js`** — the service worker. It has to sit at the **root**: a worker's scope can never rise above its own directory, so `/assets/sw.js` could not control `/blog/`.
- **`offline.html`** → `/offline/`, the fallback for a page never visited before.

Registration lives in `_includes/pwa.html`, deferred to the `load` event so it doesn't compete for bandwidth with the page the visitor is waiting for. If registration is refused (plain http, private mode, policy) the site behaves exactly as before.

The caching strategy is deliberately conservative, because a bad service worker on a live site serves stale content for a long time and cannot be fixed by deleting the file:

- **Freshness comes from the network, not from cache invalidation.** HTML is always **network-first**, so an edited post shows up on the first online load. Offline it falls back to the copy from the last visit, then to `/offline/`.
- **The cache name is not versioned per build.** The daily cron rebuild would otherwise wipe every visitor's offline cache once a day for nothing. Bump `CACHE` only when the *strategy* changes.
- The stylesheet (`/assets/css/main-<hash>.css`, named after its content), fonts, PWA icons and favicons are **cache-first** (immutable under a stable name). The stylesheet is also in the precache, from `site.css_path` (`sw.js` goes through Liquid), so `/offline/` is styled; a new hash means a new `sw.js`, which the browser installs as an update. Old hashes stay in the cache, about 100 KB per change of styles, and pages cached for offline still point at them. Everything else under `/assets/images/` is **stale-while-revalidate**, so an image replaced under the same filename fixes itself on the next visit rather than sticking forever.
- `search.json`, `feed.xml`, `sitemap.xml` and `robots.txt` are **never cached**: they are regenerated on every build, and a stale search index is worse than a network error.
- Cross-origin requests are left alone — YouTube thumbnails (`i.ytimg.com`) stay on the network and its own caching.

**To disable it**, deleting `sw.js` is not enough: browsers that already installed it keep using it. Replace the file's body with an unregister-and-clear worker (the recipe is in a comment at the top of `sw.js`) and deploy that.

Icons are generated from `scripts/pwa_icon.html` with **`ruby scripts/generate_pwa_icons.rb`** (Chrome screenshot at 512×512, then the first of `sips`, `magick`, `convert` or `ffmpeg` down to 192 — four of them because none is available everywhere, see #141 in [Deployment](deployment.md)) into `assets/images/pwa/` and committed — the same manual-step-plus-committed-PNG pattern as the OG card. The maskable variant shrinks the mark to ~62 %, because Android crops icons with a mask (often a circle) and would eat the corners of the full-bleed version.

Verified with a Node harness that loads the built `sw.js` into a sandbox with mocked service-worker globals and asserts the routing (22 checks: precache contents, old-cache cleanup, what is bypassed, network-first on HTML, offline fallbacks, stale-while-revalidate, cache-first fonts), plus a real-browser registration check through the DevTools protocol. Worth confirming once after the first deploy in DevTools → Application → Service Workers.

## Directory map

| Path | Purpose |
|---|---|
| `_config.yml` | Site identity, social handles, plugins, feature toggles (see below). |
| `_posts/` | All content — blog posts and projects (see [Writing Content](writing-content.md)). |
| `_layouts/` | `compress` → `default` → `page` → `post` chain described above. |
| `_includes/` | Partials: `nav`, `footer`, `author`, `related`, `pagination`, `read-time`, `social-links`, `blog-post` (listing item), `youtube-facade` (lazy YouTube player, loaded on posts), `series` ("Part N of M" box), `giscus` (comments, inert until configured), `theme-init` (reads the saved theme in `<head>`, before first paint), `pwa` (service-worker registration), `interactions` (image fade-in, view-transition naming, spotlight, counters, the copy button of the code blocks, theme toggle), `projects-filter`, analytics snippets, and `style.scss` (Sass entry point). |
| `_plugins/` | Custom build-time Ruby plugins (`lazy_images.rb`, `responsive_images.rb`, `og_image.rb`, `youtube_thumbnails.rb`, `toc.rb`, `photo_gallery.rb`). These **run** — see "Custom plugins" below. |
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
| `map.html` | `/map` — Leaflet map of every post with `lat`/`lng` front matter (toggle: `map` in `_config.yml`). One marker per **coordinate**, not per post: posts sharing a point (12 at Carroponte, 8 at Ippodromo La Maura) are listed together in a scrollable popup, otherwise the markers cover each other and only the top one can be opened. The popup is built with DOM nodes, never by concatenating HTML — see the jemoji warning in the file — and the Leaflet stylesheet is overridden in a `<style>` inside `map.html` because the site CSS is linked in the `<head>` and would lose to a stylesheet the body loads later. The tiles follow the theme with CSS alone: OpenStreetMap draws them light only, so on the dark theme the tile pane (not the markers) is inverted, with the same three-step order as the palettes. The page is `wide: true`. Markers are `divIcon`s in the accent, larger and numbered when they hold more than one post, with an `aria-label`. Places closer than 40px at the current zoom are merged into one ringed marker with the total (no plugin: a greedy pass from the busiest place, recomputed on every `zoomend`), because around Milan dozens of places within a few kilometres drew a blob of overlapping circles; a click on it, or Enter and Space, which Leaflet 1.9 does not wire to markers, zooms to its places. The list under the map is in year columns; Leaflet comes from unpkg with SRI hashes. Under the map, a `<details>` lists every geolocated post by year: the same content for keyboard and screen reader users, without JavaScript and for search engines. Titles lose their emoji shortcodes (`strip_emoji_shortcodes`, `_plugins/text_filters.rb`) so jemoji never re-parses the page. Today: 168 geolocated posts. Coordinates come from `recordingDetails.location` on YouTube — `scripts/sync_youtube.rb` for new posts, `scripts/resync_locations.rb` for the ones that already exist. |
| `fitness.html` | `/fitness` — workout PR tables + SVG charts from `_data/workouts.yml` (toggle: `fitness`). |
| `gear.md` | `/gear` — equipment list (toggle: `gear`). |
| `_data/workouts.yml` | Data source for `/fitness`. |
| `_data/skills.yml` | The curated stack: groups of skills, each with **where** it was used (`work`, `earlier`, `projects`), one line of detail and an optional public repo. Rendered by the "What I work with" tiles on the home and by `/stack/`. |
| `_data/skills_map.yml`, `_data/skills_repos.yml` | GitHub → skills. The map (hand-written) turns a repo's primary language or a topic into a skill name and group; `scripts/sync_skills.rb`, hourly in `github-sync.yml`, writes the generated file: every mapped skill with its public repos, and per group the skills `skills.yml` lacks. The templates show the repos under a skill (`_includes/stack-repos.html`: five links, then "and N more") and add the new skills to the home tiles and `/stack/`, skipping any name already in `skills.yml`. |
| `stack.html` | `/stack/` — every skill with where it was used, its detail and its repo, filterable by where (`_includes/stack-filter.html`, hidden without JS). Built with nava-ui's components — the bento grid and the marked pills, vendored as `_sass/vendor/_nava-bento.scss` and `_nava-marks-pills-and-legends.scss` and imported in `_includes/style.scss` — so the site has no styles of its own for it. A group's `tile` in `_data/skills.yml` sets its tile size on the home (`feature`, `w3`, `h2`, …); `_includes/stack-pill.html` maps a kind of "where" to the pill and the mark. |
| `blog/index.html` | Blog listing; lives in its own folder to support Jekyll pagination if re-enabled. |
| `projects.html` | Projects listing; filters `site.posts` on `projects: true`, honours `externalLink` and `star`. |
| `tags.html` | Tag cloud + per-tag post lists, anchored by slugified tag name. |
| `about.md` | About page (`/about/`): nava-ui's `nv-profile` (photo, name as the `<h1>`, links from `social.links`), a row of `nv-pill` and `nv-award` for Sevilla FC+; `custom_header: true` because the profile carries the `<h1>`. No work history: it lives on the CV and LinkedIn, and the page says only where and since when in one sentence. |
| `play.html` | `/play/` — Ridge run, a one-button runner on a `<canvas>`: the hiker jumps rocks, pines and low choughs and stays under the high ones. The script is `assets/js/ridge-run.js`, a static file (no Liquid, no jemoji) loaded only here; the ranges are the channel banner's ridge points, the colours are read from the `--color-*` tokens and read again when `data-theme` or the system scheme changes, the best distance is in `localStorage` (wrapped in try/catch). Difficulty grows in two stages: up to about 54 s (2,600 m) the speed rises fast, 330 → 820 px/s, and choughs (250 m) and rock piles (600 m) join; then it keeps rising slowly to 980 px/s, a low chough can come with a high one 0.85 s behind it (1,500 m), and the gaps tighten to 90% by 5,000 m. Every gap stays longer than a tapped jump (about 0.55 s in the air), so a run is always survivable. The game block starts `hidden` and the script shows it. Styles in `_sass/pages/content-pages.scss`; linked from the footer (`play` toggle) and the 404. |
| `archive.html` | `/archive/` — every post grouped by year (pure Liquid). |
| `stats.html` | `/stats/` — totals, posts per year, most used project tags; CSS bars, no JS. The bars are nava-ui's `nv-bars` (`_sass/vendor/_nava-bars.scss`): every row shares the columns of the list through `subgrid`, so all bars start on the same line however long the label. |
| `videos.html` | `/videos/` — opens with the channel banner (`_includes/channel-banner.html`, the `nv-banner` component of nava-ui since v0.5.0, its styles in `_sass/vendor/_nava-banner.scss` from `scripts/sync_nava_ui.sh`; only the space below it is in `page.sass`): the YouTube banner of the `cv` repo redrawn with the kit's tokens, so it follows both themes; video count, places on the map and the latest video are computed from the posts at build time, so every YouTube sync updates it. The green ridge draws itself on load and the three ridges drift at different speeds on scroll (scroll-driven animation, behind `@supports` and `prefers-reduced-motion`). Then the grid of every post embedding a YouTube facade. |
| `search.html`, `search.json` | `/search/` — client-side search over the build-time index (194 entries, 44 KB). |
| `assets/images/`, `assets/video/` | Media; `.MOV` files tracked via Git LFS. |
| `404.html` | GitHub Pages custom 404. Deliberately minimal: the big numeral, the `<h1>` and one line of explanation — nav and footer come from the layout and are the only way out it needs. Don't add listings here. |

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
| `description` | Site-wide meta description and `og:description` fallback for any page without its own `description:`. Not decorative — see "Search engines". |
| `tagline` | Second half of the home page `<title>`: `"{name} — {tagline}"`. |
| `social` | `name` + `links`: the profile URLs that become the `sameAs` of the `Person` JSON-LD (`_includes/schema-person.html`). |
| `google_site_verification` | Search Console verification token for the `https://allan-nava.github.io/` property; `jekyll-seo-tag` turns it into the verification meta on every page. Removing it un-verifies the property — see "Search engines". |
| `analytics-google` | GA4 measurement ID — `G-X841VQSHB8` (active). Comment it out to stop collecting; the include only renders when it is set. See "Analytics". |

Social handles (`github`, `instagram`, `linkedin`, `youtube`, `dev`) feed `_includes/social-links.html`. **`twitter` is the exception: it is nested as `twitter.username`**, because `jekyll-seo-tag` reads only `site.twitter.username` — with the flat form every page shipped `<meta name="twitter:site" content="@">`. The `authors:` map defines the author block data; post `author` fields must reference a key in it.

## Plugins

Declared in `_config.yml` and provided by the `github-pages` gem (all whitelisted by GitHub Pages):

- `jekyll-seo-tag` — meta/OpenGraph tags via `{% seo title=false %}` in `default.html` (the `<title>` is composed by the layout; see "Search engines")
- ~~`jekyll-feed`~~ — **removed** (#160). The plugin has no way to exclude `hidden: true` posts, and it takes the latest N posts by date, so five of the ten entries in `/feed.xml` were repo cards generated by `sync_github.rb`, reshuffled every hour by `github-sync.yml` even when nothing had been written. The two feeds are hand-written templates instead — see "Feeds" below.
- `jekyll-sitemap` — `/sitemap.xml` (350+ URLs). **It also generates a `robots.txt` containing the `Sitemap:` line — but only when the repo has none** (`@site.pages << robots unless file_exists?("robots.txt")`). This repo ships its own `robots.txt`, so that automatic declaration never happened and the host advertised no sitemap at all until it was added. `robots.txt` is now a **Liquid template** (it carries empty front matter so Jekyll renders it): it prints the fixed host `Sitemap:` line plus one line per entry in `_data/pages_sitemaps.yml`. Crawlers read `robots.txt` only from the host root, so this one file speaks for every project site under `allan-nava.github.io/<repo>/` too — hence one `Sitemap:` per site. That data file is **generated in CI** by `scripts/sync_robots_sitemaps.rb` (workflow `robots-sync.yml`, config `_data/robots_sync.yml`): it lists only `Allan-Nava`-owned Pages sites whose `sitemap.xml` returns 200, so nothing is declared that isn't actually served. See `docs/deployment.md` for the workflow. Below the `*` group, `robots.txt` names the AI crawlers one by one, from `_data/ai_crawlers.yml` (#190): the ones that fetch a page to answer a question and cite it (`OAI-SearchBot`, `ChatGPT-User`, `Claude-SearchBot`, `Claude-User`, `PerplexityBot`) and the ones that collect pages to train a model (`GPTBot`, `ClaudeBot`, `Google-Extended`, `CCBot`). All are allowed; naming them writes the choice down, and `allow: false` on a line turns it into `Disallow: /` for that crawler. Each group carries its own rule because a crawler obeys only the most specific group that names it and ignores `*`. `checkfleet.yml` asserts that the live file still names them.
- `/llms.txt` (#191) — an index of the site for language models, in the format proposed at llmstxt.org (a proposal, not a standard; some assistants and tools fetch it, the large crawlers have not said they read it). A Liquid template at the root, `layout: null`, `sitemap: false`: an H1, the site description as a blockquote, a paragraph of who and what with the `social.links` profiles, then sections of `- [title](url): description` lines: About (about, stack, gear), Projects (the page and the 12 latest project posts with a repository), Blog (the page and the 12 latest notes), Videos (the page and the 6 latest posts synced from the channel, slug `youtube-`), Optional (archive, tags, map, fitness, stats, search, feed, sitemap). Everything comes from front matter at build time, so it never goes stale; titles go through `strip_emoji_shortcodes` because jemoji renders only HTML. In `NEVER_CACHE` of `sw.js`, and asserted by `checkfleet.yml`.
- `jemoji` — `:emoji:` shortcodes
- `jekyll-gist` — GitHub gist embeds

- `jekyll-paginate` — paginates `/blog` (`paginate: 10`); see "Pagination" below.

`jekyll-admin`, the `/admin` UI of `jekyll serve`, was removed in #184: nobody used it, and its `rack` 1.6 and `sinatra` 1.4 were 40 of the 51 Dependabot alerts. The same change updated `activesupport` to 8.1.4.1, `addressable` to 2.10.0 and `nokogiri` to 1.19.7 within what `github-pages` 232 allows. The alert left open is `rubyzip` (path traversal, fixed in 3.4.0): `jekyll-remote-theme`, a dependency of `github-pages`, pins it below 3.0, and this site uses no remote theme, so the vulnerable code (extracting a downloaded theme archive) never runs.

## Feeds

Two Atom feeds, both hand-written templates in the repo root — there is no feed plugin (see above):

| File | URL | Contents |
|---|---|---|
| `feed.xml` | `/feed.xml` | The blog: `site.posts` minus `hidden: true`, newest 20. This is the feed in the `<head>` of every page and behind the footer's RSS link. |
| `feed-projects.xml` | `/projects/feed.xml` | The project posts, newest 20. Linked from the `<head>` of `/projects/` only, via `projects_feed: true` in its front matter — the footer keeps one RSS link, the blog's. |

Three things the templates get right that are easy to get wrong:

- **`<content>` lives in CDATA, so it must not be passed through `xml_escape`.** Escaped entities inside a CDATA section are shown literally by readers.
- **`strip_html` on a video post's body leaves nothing.** The body of the 114 YouTube posts is a single `<lite-youtube>` element, so a naive `content | strip_html | truncatewords` produced 20 entries with an empty `<summary>` *and* an empty `<content>`. The summary comes from `description` (always set), and the content opens with the thumbnail linked to the post; when the body has no text at all, it closes with a link back to the post.
- **URLs are absolutised.** A reader renders the entry with no base URL, so `src="/assets/…"` would break. Both templates rewrite `src="/` and `href="/` to the full host.

Because nothing regenerates these files, both are probed by `checkfleet.yml` on the live site (post-deploy smoke and the 10-minute uptime run).

## Custom plugins (`_plugins/`)

Unlike a site built on GitHub's own Pages infrastructure (which runs Jekyll in `--safe` mode and ignores `_plugins/`), this site is built with a full `bundle exec jekyll build` inside GitHub Actions (see [Deployment & CI](deployment.md)). **Custom plugins in `_plugins/` therefore execute** at build time — both in CI and locally.

- `lazy_images.rb` — a `:post_render` hook that adds `loading="lazy"` + async decoding to content `<img>` tags. kramdown can't set a global image attribute, so Markdown photos would otherwise load eagerly. It skips images that already declare a `loading` attribute and the above-the-fold hero images (`title-image`, `selfie`), which stay eager as LCP candidates.
- `youtube_thumbnails.rb` — a `Generator` that fills an empty `image:` with `https://i.ytimg.com/vi/<id>/hqdefault.jpg` when the post body contains a `<lite-youtube videoid="…">` facade (114 posts today). The backfilled video posts predate the thumbnail feature, so without it the listing cards and `og:image` would be empty. It only touches in-memory document data — nothing is written back to `_posts/`.
- `card_placeholder.rb` — two Liquid filters (`card_initials`, `card_palette`) used by the listing cards to draw a monogram on a gradient when a post has no `image:`. The palette index comes from a stable hash of the title (not Ruby's `Object#hash`, which is randomised per process), so a project keeps the same colour across builds.
- `project_tags.rb` — a `Generator` that fills `site.data.project_tags` with the 12 most used tags among project posts, for the `/projects` filter chips. Counting is **per slug and per post**, which is what makes the number on a chip equal the number of cards left after filtering (Liquid can't sort a map by value, hence the plugin).
- `toc.rb` — replaces the `<div class="toc-slot"></div>` emitted by `_layouts/post.html` with a collapsible `<details>` index of the post's `h2`/`h3`, or removes it when the post has fewer than 3 headings (which is every post today — the feature kicks in for long-form articles). It reads the ids kramdown already generates, so it needs no HTML parser.
- `photo_gallery.rb` — a `:post_render` hook that wraps runs of **two or more consecutive image-only `<div>`s** in `<div class="gallery" data-photos="N">`, which `_sass/components/gallery.sass` lays out as a square-cropped grid (22 posts, 76 photos). It recognises the block both with and without the `<picture>` wrapper, so it is order-independent with respect to `responsive_images.rb`; the inner `<div>`s are left untouched, which means the grid serves the small `srcset` variants and is *lighter* than the full-width column it replaces. The attribute is `data-photos` and **not** `data-count` — the home's animated counters used to select `[data-count]` unqualified and overwrote the gallery with a digit.

## Pagination

`/blog` is paginated with `jekyll-paginate` (v1, bundled with `github-pages`): `paginate: 10` + `paginate_path: "blog/:num/"`, rendered by `_includes/pagination.html`. `blog/index.html` must stay named `index.html` in its own folder for the paginator to run. **Caveat:** v1 paginates *all* `_posts` (including `hidden: true` projects); `blog/index.html` filters those out, so the oldest pages (2019-era projects) render fewer than 10 items while recent pages are full. v2 (per-category pagination) is not whitelisted by GitHub Pages, so this is the ceiling with the stock gem.

## YouTube embeds (facade)

Video embeds use a lightweight facade instead of a raw `<iframe>`: posts contain `<lite-youtube videoid="…">` elements, and `_includes/youtube-facade.html` (self-contained CSS + a small custom element, no CDN) renders a clickable thumbnail, loading the real cookie-less player (`youtube-nocookie.com`) only on click. This is the biggest per-page win now that most posts embed video. The sync scripts emit this markup directly; `scripts/migrate_youtube_embeds.rb` converted the existing posts (see [Writing Content](writing-content.md)).

## Dependency automation

**Dependabot** (`.github/dependabot.yml`) opens weekly PRs for Ruby gems (`bundler`) and GitHub Actions versions.
