# CLAUDE.md — allan-nava.github.io

Portfolio/blog personale di Allan Nava (`https://allan-nava.github.io`), costruito con **Jekyll** sul tema [Indigo](https://github.com/sergiokopplin/indigo) e deployato su **GitHub Pages**. Contenuti in `_posts/` (blog post e progetti, ita/eng). Documentazione human-facing in `docs/`.

## Regole di lavoro (SEMPRE)

- **MAI `git push`** — lo fa sempre Allan. **Commit solo se richiesto esplicitamente.** MAI `Co-Authored-By` nei commit.
- **Validare dopo ogni modifica a `_posts/`**: `ruby scripts/validate_posts.rb` (front matter, date, riferimenti asset — no `bundle` richiesto). Gate del workflow `checks.yml` su ogni PR e del deploy.
- **Verifica link/immagini**: `rake test` (build + html-proofer, segnala 4xx). Non esiste linter né unit test — la validazione è l'html-proofer contro `_site/`.
- **Documentare SEMPRE** modifiche a build, content model o workflow: allineare i `.md` in `docs/` (getting-started, writing-content, architecture, deployment) **senza chiederlo**. Ogni cambiamento fattuale va propagato a `docs/`, `_config.yml`, template, script.
- **Nuovi contenuti** solo come `_posts/YYYY-MM-DD-slug.markdown` con front matter corretto (vedi Content model sotto). `category: blog` → `/blog`; `category: project` + `projects: true` + `hidden: true` → `/projects`.
- **Video**: MAI file `.MOV` nel repo — devono essere **embed YouTube** (vedi trappola Git LFS sotto).

## Content model

Tutto in `_posts/YYYY-MM-DD-slug.markdown`. Il campo front-matter `category` separa i due tipi:

**Blog post** (`category: blog`) — elencato su `/blog`:
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

**Progetto** (`category: project`) — elencato su `/projects`, nascosto dal blog:
```yaml
---
title: "Project Name"
layout: post
date: 2019-01-18 20:30
tag:
- javascript
projects: true       # appare nella pagina projects
hidden: true         # fuori dalla paginazione blog
category: project
author: allan
externalLink: https://example.com   # opzionale: la pagina projects linka qui
---
```

Altri flag: `star: true` (evidenzia in listing), `hidden: true` (esclude dal blog). `author` deve corrispondere a una chiave sotto `authors:` in `_config.yml` (oggi solo `allan`).

## Comandi

```bash
bundle install                 # dipendenze (github-pages, html-proofer, jekyll-admin)
bundle exec jekyll serve       # dev server http://localhost:4000 (admin UI su /admin)
bundle exec jekyll build       # build in _site/
rake test                      # build + html-proofer (4xx link/immagini rotte)
ruby scripts/validate_posts.rb # validazione veloce dei post — no bundle
```

## Trappole note / regole tecniche

- **Git LFS**: i `.MOV` sotto `assets/video/` sono LFS-tracked e la checkout CI **non** scarica gli oggetti LFS → i video self-hosted arrivano al sito live come pointer file rotti. Nuovi video = **embed YouTube**, non file nel repo.
- **Nessun branch `main`**: si lavora su `master`. Il deploy parte da push su `master`.
- **Ruby version**: il workflow `jekyll.yml` builda con **Ruby 3.0** / `JEKYLL_ENV=production`. Deve restare allineata a `Gemfile.lock`.
- **Paginazione disattivata** (commentata in `_config.yml`): `/blog` elenca tutti i post.
- **Immagini nei post**: usare **URL relativi** per coerenza (vedi commit recenti).
- `_includes/style.scss` è l'entry point Sass che importa tutto da `_sass/` (`base/`, `components/`, `pages/`).

## Deployment

Push su `master` → GitHub Pages via `.github/workflows/jekyll.yml` (push + cron giornaliero 10:00 UTC + dispatch manuale): build Ruby 3.0 / production, deploy dell'artifact `_site/`. `uptime.yml` fa curl al sito live ogni 10 minuti. `checks.yml` gira `validate_posts.rb` su ogni PR.

## Architettura

- `_config.yml` — identità sito, social, toggle feature (`projects`, `about`, `blog`, `read-time`, `show-tags`, `related`, `show-author`, `animation`, `width`).
- `_layouts/` — `default.html` (wrapper, estende `compress.html` per minify), `page.html`, `post.html`.
- `_includes/` — partial condivisi (nav, footer, author, related, analytics, social).
- Pagine top-level = template Liquid sottili: `index.html`, `blog/index.html`, `projects.html`, `tags.html`, `about.md`, `404.html`.
- `assets/images/` e `assets/video/` — media dei post; profilo in `assets/images/profile.jpg`.

## Puntatori

- Documentazione: `docs/` — `getting-started.md`, `writing-content.md`, `architecture.md`, `deployment.md`, `ROADMAP.md`.
- Script: `scripts/validate_posts.rb` (gate PR/deploy), `scripts/sync_youtube.rb`, `scripts/sync_strava.rb`.
- Workflow CI: `.github/workflows/` — `jekyll.yml` (deploy), `checks.yml` (validazione PR), `youtube-sync.yml` (post automatici ogni 3h), `strava-sync.yml` (post da attività, richiede secret), `uptime.yml` (probe), `bootstrap-milestone.yml` (one-shot issue/milestone).
- Pagine extra (toggle in `_config.yml`): `map.html` (`/map`, post con `lat`/`lng`), `fitness.html` (`/fitness`, dati in `_data/workouts.yml`), `gear.md` (`/gear`).
