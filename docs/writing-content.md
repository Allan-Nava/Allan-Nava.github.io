# Writing Content

All content lives in `_posts/` as Markdown files named `YYYY-MM-DD-slug.markdown`. The `category` front matter field decides where a post shows up:

- `category: blog` → listed on [/blog](https://allan-nava.github.io/blog/)
- `category: project` → listed on [/projects](https://allan-nava.github.io/projects/) (when combined with `projects: true`)

## Blog post

```yaml
---
title: "Athens 2k23 🇬🇷"
layout: post
date: 2024-04-27 13:00
tag:
- athens
- greece
- vlog
image: ""
headerImage: false
description: "Short SEO description shown in listings and meta tags"
category: blog
author: allan
---

## Post body in Markdown…
```

## Project

```yaml
---
title: "Tangram Site"
layout: post
date: 2019-01-18 20:30
tag:
- site
- javascript
image: ""
headerImage: false
projects: true       # required: makes it appear on /projects
hidden: true         # required: keeps it out of the blog listing
description: "One-line project description"
category: project
author: allan
externalLink: https://example.com   # optional, see below
---
```

## Front matter reference

| Field | Type | Effect |
|---|---|---|
| `title` | string | Post title (`<h1>` and listings). |
| `layout` | string | Always `post` for content in `_posts/`. |
| `date` | `YYYY-MM-DD HH:MM` | Publication date; must match the date in the filename. |
| `tag` | list | Tags shown under the title and aggregated on `/tags`. |
| `category` | `blog` \| `project` | Routes the post to the blog or projects listing. |
| `author` | string | Must match a key under `authors:` in `_config.yml` (currently only `allan`); renders the author block at the end of the post. |
| `description` | string | Used by `jekyll-seo-tag` and post listings. |
| `image` | path/URL | Header image; only rendered when `headerImage: true`. |
| `headerImage` | bool | Shows `image` above the title. |
| `projects` | bool | Includes the post on `/projects` (`projects.html` filters on it). |
| `hidden` | bool | Excludes the post from the blog listing (`blog/index.html`). |
| `externalLink` | URL | On `/projects`, the item links to this URL instead of the post page. |
| `star` | bool | Adds the `star` CSS class to highlight the item in listings. |
| `lat`, `lng` | float | Geolocates the post: it appears as a marker on `/map`. |

Notes:

- **Prev/next navigation** only renders for categories listed in `post-advance-links` in `_config.yml` (currently `[blog]`).
- **Read time** and **related posts** blocks are controlled globally by `read-time` and `related` in `_config.yml`, not per post.
- Emoji shortcodes (e.g. `:smile:`) work everywhere thanks to the `jemoji` plugin.
- Workout PRs shown on `/fitness` live in `_data/workouts.yml` — add a record (date, kg, optional post URL) whenever a PR falls.

## Media

- **Images**: put them in `assets/images/` and reference them with a root-relative path (`/assets/images/foo.jpg`). Don't hotlink repo files through `github.com/...?raw=true` — it adds a redirect on every load and breaks local previews. Resize photos to ~1600px width before committing; multi-MB camera originals slow the site down for nothing.
- **Video**: do **not** commit video files. Existing `.MOV` files in `assets/video/` go through Git LFS, and since CI doesn't fetch LFS objects they reach the live site as broken pointer files (see [Deployment & CI](deployment.md)). Upload videos to YouTube and embed them with the **facade** element (not a raw `<iframe>`):

```html
<lite-youtube videoid="VIDEO_ID" playlabel="Optional title"></lite-youtube>
<!-- portrait Shorts: add data-short -->
<lite-youtube videoid="VIDEO_ID" data-short></lite-youtube>
```

`_includes/youtube-facade.html` renders a clickable thumbnail and only loads the real (cookie-less) player on click — a big performance win, since most posts embed video. Plain `<iframe>` embeds still work, but prefer `<lite-youtube>`; the YouTube sync scripts emit it automatically, and `scripts/migrate_youtube_embeds.rb` converted all existing posts. For auto-generated posts the YouTube thumbnail is also set as `image:` (og:image / listing preview).

- **Side-by-side layout** (image next to text), used by several project posts:

```html
<div class="side-by-side">
    <div class="toleft">
        <img class="image" src="…" alt="…">
    </div>
    <div class="toright">
        <p>Text…</p>
    </div>
</div>
```

- **GitHub gists** can be embedded with the `jekyll-gist` plugin: `{% gist user/gist_id %}`.

## Publishing

Commit the new file to `master` and push — the GitHub Actions workflow builds and deploys automatically (see [Deployment & CI](deployment.md)). Posts dated in the future are not published until the date passes and the site rebuilds (the daily scheduled workflow takes care of that).

New YouTube videos don't need a hand-written post at all: the `youtube-sync.yml` workflow creates one automatically within ~3 hours of publishing (tags `youtube` + `video`/`short`). If you prefer to write the post yourself, just embed the video with `<lite-youtube videoid="…">` — the sync skips any video whose ID already appears in `_posts/`.
