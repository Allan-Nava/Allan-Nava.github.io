# Getting Started

## Prerequisites

- **Ruby ≥ 3.1** — `html-proofer` is pinned to `~> 5.0`, which needs 3.1+, so a 3.0 toolchain cannot install this bundle at all (`bundle install` fails, and `bundle exec jekyll build` dies with `Bundler::GemNotFound`). The repo ships a `.ruby-version` with **3.3.12**, matching the `ruby-version: '3.3'` used by CI: with rbenv, `rbenv install 3.3.12` then `gem install bundler -v 2.4.22` (the version in `BUNDLED WITH`) is all it takes.
- **UTF-8 locale** — the Sass pipeline reads accented characters, so a non-UTF-8 shell fails the build with `Invalid US-ASCII character`. Export `LANG=en_US.UTF-8` (and `LC_ALL=en_US.UTF-8`) before building; CI runners already do.
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
ruby scripts/check_contrast.rb   # WCAG contrast of the palette, on both themes (stdlib only)
ruby scripts/optimize_images.rb  # WebP+AVIF variants for new images (needs cwebp and ffmpeg; DRY_RUN=1)
ruby scripts/generate_pwa_icons.rb  # regenerate the installable-app icons (needs Chrome)
ruby scripts/generate_og_cards.rb   # per-post social cards (needs Chrome; LIMIT=5/DRY_RUN=1)
rake test                        # builds the site, then reports 4xx broken links/images (html-proofer)
rake test_internal               # same, but skips external links (fast, and works around the crash below)
```

`check_contrast.rb` reads the `palette-dark` / `palette-light` mixins straight out of `_sass/base/tokens.scss`, so it can't drift from the real CSS. Run it after touching any colour: it fails both when a pair drops below 6:1 and when a token is added to only one of the two themes (which is how a colour silently stops following the theme). Lighthouse only audits whichever theme the page loads with, so it won't catch the other one.

Both rake tasks mirror the flags CI uses. To call html-proofer directly:

```bash
bundle exec htmlproofer ./_site --disable-external --allow-hash-href \
  --ignore-empty-alt --assume-extension ".html" --ignore-urls "/localhost/"
```

Those names are **html-proofer 4/5**: 3.x used `--url-ignore` / `--empty-alt-ignore` and a valueless `--assume-extension`. If you see the old spellings anywhere, they are stale. In 5.x the booleans are documented as `--[no-]flag`, but the plain `--flag` form still works, so nothing changed between 4 and 5 for the CLI.

The same checks run in CI on every pull request (see [Deployment & CI](deployment.md)). `--ignore-empty-alt` is there because `alt=""` is the correct markup for decorative images (the nav avatar, listing thumbnails, where the link supplies the accessible name); a **missing** alt attribute is still an error, which is how the upgrade to 4.x caught one.

Expect some noise from long-dead external links in old posts; treat failures on *internal* links and images as real problems.

**External links are noisy, not broken.** A full `rake test` checks ~1440 external links and currently reports ~1010 failures: a decade of posts pointing at Heroku apps and sites that no longer exist. That is why `checks.yml` only validates internal links, and `link-check.yml` reports the external ones to an issue once a month instead of gating.

The old `Segmentation fault` in `ethon`/libcurl that used to kill the external phase on macOS/arm64 did **not** reproduce with html-proofer 5 — a full local run completed cleanly. `ethon` is still in the bundle, so the crash may simply have moved rather than gone; if it comes back, `rake test_internal` remains the local workaround.
