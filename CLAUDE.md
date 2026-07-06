# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal portfolio/blog of Allan Nava (https://allan-nava.github.io), built with Jekyll on the [Indigo theme](https://github.com/sergiokopplin/indigo) and deployed to GitHub Pages. Content is mostly Italian/English blog posts and project showcases in `_posts/`.

Full human-facing documentation lives in `docs/` (getting started, content authoring, architecture, deployment) — keep it in sync when changing build, content model, or workflows.

## Commands

```bash
bundle install                 # install dependencies (github-pages, html-proofer, jekyll-admin)
bundle exec jekyll serve       # local dev server at http://localhost:4000 (jekyll-admin UI at /admin)
bundle exec jekyll build       # build the site into _site/
rake test                      # build + validate all links/HTML with html-proofer
./travis.sh                    # build + html-proofer checking only 4xx errors
```

There is no linter or unit test suite — validation is the html-proofer run against the built `_site/`.

## Deployment

Pushes to `master` trigger GitHub Pages deployment via **two** workflows that both build with Jekyll and deploy the `_site/` artifact: `.github/workflows/jekyll.yml` (push only) and `.github/workflows/refresh.yml` (push + daily cron at 10:00 UTC). Both use Ruby 3.0 and `JEKYLL_ENV=production`. `uptime.yml` pings the live site every 10 minutes. There is no `main` branch — work on `master`.

## Content model

All content lives in `_posts/YYYY-MM-DD-slug.markdown`. A single `category` front-matter field splits posts into two kinds:

**Blog post** (`category: blog`) — listed on `/blog` (`blog/index.html`):

```yaml
---
title: "Post Title"
layout: post
date: 2024-04-27 13:00
tag:
- some-tag
image: ""
headerImage: false
description: "Short description"
category: blog
author: allan
---
```

**Project** (`category: project`) — listed on `/projects` (`projects.html`), hidden from the blog list:

```yaml
---
title: "Project Name"
layout: post
date: 2019-01-18 20:30
tag:
- javascript
projects: true       # makes it appear on the projects page
hidden: true         # keeps it out of blog pagination
category: project
author: allan
externalLink: https://example.com   # optional: projects page links here instead of the post
---
```

Other recognized front-matter flags: `star: true` (highlights an item in listings), `hidden: true` (excludes from blog listing). The `author` value must match a key under `authors:` in `_config.yml` (currently only `allan`).

## Architecture

- `_config.yml` — site identity, social handles, and feature toggles (`projects`, `about`, `blog`, `read-time`, `show-tags`, `related`, `show-author`, `animation`, `width`). Pagination is currently commented out, so `/blog` lists all posts.
- `_layouts/` — `default.html` (wraps everything, extends `compress.html` for HTML minification), `page.html`, `post.html`.
- `_includes/` — shared partials (nav, footer, author block, related posts, analytics, social links). `style.scss` here is the Sass entry point importing everything from `_sass/` (organized as `base/`, `components/`, `pages/`).
- Top-level pages are thin Liquid templates: `index.html` (home), `blog/index.html`, `projects.html` (filters posts with `projects: true`), `tags.html`, `about.md`, `404.html`.
- `assets/images/` and `assets/video/` hold media referenced by posts; the profile picture is `assets/images/profile.jpg`.
