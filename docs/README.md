# Documentation

Documentation for [allan-nava.github.io](https://allan-nava.github.io) — a personal portfolio and blog built with [Jekyll](https://jekyllrb.com/) on the [Indigo theme](https://github.com/sergiokopplin/indigo) and hosted on GitHub Pages.

| Guide | What it covers |
|---|---|
| [Getting Started](getting-started.md) | Prerequisites, installation, running the site locally |
| [Writing Content](writing-content.md) | Creating blog posts and projects, front matter reference, media |
| [Architecture](architecture.md) | How the site is put together: layouts, includes, Sass, configuration |
| [Deployment & CI](deployment.md) | GitHub Actions workflows, content sync (YouTube/Strava), testing, uptime monitoring |
| [Roadmap](ROADMAP.md) | Backlog versionato (milestone v2.0 → v3.0), feature da implementare |

## Quick reference

```bash
bundle install               # install dependencies
bundle exec jekyll serve     # dev server → http://localhost:4000 (admin UI at /admin)
bundle exec jekyll build     # production build into _site/
rake test                    # build + validate HTML and links
```

New blog post → drop a file in `_posts/` named `YYYY-MM-DD-slug.markdown` with `category: blog`.
New project → same, with `category: project`, `projects: true`, `hidden: true`.
See [Writing Content](writing-content.md) for the full front matter reference.
