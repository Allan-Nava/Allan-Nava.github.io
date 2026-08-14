# Getting Started

## Prerequisites

- **Ruby** — CI builds with Ruby 3.0 (`.github/workflows/jekyll.yml`); any 3.x works locally. To match CI exactly with a version manager: `brew install rbenv ruby-build && rbenv install 3.0.7` (Ruby 3.0 is EOL, so it compiles from source).
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
ruby scripts/optimize_images.rb  # WebP variants for new images (needs cwebp; DRY_RUN=1 to preview)
ruby scripts/generate_pwa_icons.rb  # regenerate the installable-app icons (needs Chrome)
rake test                        # builds the site, then reports 4xx broken links/images (html-proofer)
rake test_internal               # same, but skips external links (fast, and works around the crash below)
```

`check_contrast.rb` reads the `palette-dark` / `palette-light` mixins straight out of `_sass/base/tokens.scss`, so it can't drift from the real CSS. Run it after touching any colour: it fails both when a pair drops below 6:1 and when a token is added to only one of the two themes (which is how a colour silently stops following the theme). Lighthouse only audits whichever theme the page loads with, so it won't catch the other one.

If `rake` isn't in your bundle, call html-proofer directly with the CI flags:

```bash
bundle exec htmlproofer ./_site --disable-external --allow-hash-href \
  --empty-alt-ignore --assume-extension --url-ignore "/localhost/"
```

The same checks run in CI on every pull request (see [Deployment & CI](deployment.md)). Both rake tasks mirror the flags CI uses (`--empty-alt-ignore`, `--allow-hash-href`, `--assume-extension`): `alt=""` is the correct markup for decorative images (the nav avatar, listing thumbnails, where the link supplies the accessible name), and without that flag html-proofer 3 reports every one of them.

Expect some noise from long-dead external links in old posts; treat failures on *internal* links and images as real problems.

**Known local crash:** on macOS/arm64 the external-link phase of `rake test` can die with a `Segmentation fault` inside `ethon`/libcurl (`ethon-0.12.0/lib/ethon/multi/operations.rb`) while checking the ~1000 external links. It's an environment issue in that native stack, not a site failure — use `rake test_internal` locally and let CI do the external pass.
