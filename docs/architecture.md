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
- `_layouts/page.html` adds the site header/nav; `_layouts/post.html` adds title, date, read time, tags, prev/next navigation, related posts, author block, and (if configured) Disqus comments.

## Directory map

| Path | Purpose |
|---|---|
| `_config.yml` | Site identity, social handles, plugins, feature toggles (see below). |
| `_posts/` | All content — blog posts and projects (see [Writing Content](writing-content.md)). |
| `_layouts/` | `compress` → `default` → `page` → `post` chain described above. |
| `_includes/` | Partials: `nav`, `footer`, `author`, `related`, `pagination`, `read-time`, `social-links`, `blog-post` (listing item), analytics snippets, and `style.scss` (Sass entry point). |
| `_sass/base/` | `variables.sass` (colors, fonts, breakpoints), `general`, `helpers`, `normalize`, `syntax` (code highlighting). |
| `_sass/components/` | One file per UI component (header, nav, footer, author, pagination, side-by-side, spoiler, …). |
| `_sass/pages/` | Page-specific styles (home/blog/projects listing, post, tags). |
| `index.html` | Home page (thin `page`-layout shell; content comes from config + includes). |
| `blog/index.html` | Blog listing; lives in its own folder to support Jekyll pagination if re-enabled. |
| `projects.html` | Projects listing; filters `site.posts` on `projects: true`, honours `externalLink` and `star`. |
| `tags.html` | Tag cloud + per-tag post lists, anchored by slugified tag name. |
| `about.md` | About page (`/about/`). |
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
| `width` | Content width: `normal` (560px) or `large` (810px). |
| `paginate`, `paginate_path` | Blog pagination — currently commented out, so `/blog` lists everything. |
| `analytics-google` | Google Analytics ID; the include is only rendered when set. |

Social handles (`github`, `instagram`, `linkedin`, `youtube`, `twitter`, `dev`) feed `_includes/social-links.html`. The `authors:` map defines the author block data; post `author` fields must reference a key in it.

## Plugins

Declared in `_config.yml` and provided by the `github-pages` gem (all whitelisted by GitHub Pages):

- `jekyll-seo-tag` — meta/OpenGraph tags via `{% seo %}` in `default.html`
- `jekyll-feed` — RSS at `/feed.xml`
- `jekyll-sitemap` — `/sitemap.xml`
- `jemoji` — `:emoji:` shortcodes
- `jekyll-gist` — GitHub gist embeds

`jekyll-admin` (local-only) adds the `/admin` UI when serving locally; it plays no role in production builds.

## Dependency automation

**Dependabot** (`.github/dependabot.yml`) opens weekly PRs for Ruby gems (`bundler`) and GitHub Actions versions.
