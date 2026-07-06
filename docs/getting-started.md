# Getting Started

## Prerequisites

- **Ruby** — CI builds with Ruby 3.0 (`.github/workflows/jekyll.yml`); any 3.x works locally.
- **Bundler** — `gem install bundler`.
- **Git LFS** — `.MOV` video files in `assets/video/` are stored with [Git LFS](https://git-lfs.com/) (see `.gitattributes`). Install it and run `git lfs install` before cloning, otherwise videos come down as pointer files.

The site is pinned to the [`github-pages`](https://github.com/github/pages-gem) gem (Jekyll 3.9.0), which guarantees the local build matches what GitHub Pages produces.

## Installation

```bash
git clone https://github.com/Allan-Nava/Allan-Nava.github.io.git
cd Allan-Nava.github.io
bundle install
```

## Running locally

```bash
bundle exec jekyll serve
```

- Site: <http://localhost:4000>
- Admin UI: <http://localhost:4000/admin> — provided by the `jekyll-admin` gem; lets you create and edit posts, pages, and config from the browser.

The server rebuilds automatically on file changes. Changes to `_config.yml` require a restart.

## Building

```bash
bundle exec jekyll build        # output in _site/ (git-ignored)
JEKYLL_ENV=production bundle exec jekyll build   # what CI runs
```

## Testing

```bash
ruby scripts/validate_posts.rb   # fast content check: front matter, dates, titles, asset files (stdlib only)
rake test                        # builds the site, then reports 4xx broken links/images (html-proofer)
```

The same checks run in CI on every pull request (see [Deployment & CI](deployment.md)).

Expect some noise from long-dead external links in old posts; treat failures on *internal* links and images as real problems.
