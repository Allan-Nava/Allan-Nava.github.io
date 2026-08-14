# CLAUDE.md — allan-nava.github.io

Portfolio/blog personale di Allan Nava (`https://allan-nava.github.io`), costruito con **Jekyll** sul tema [Indigo](https://github.com/sergiokopplin/indigo) e deployato su **GitHub Pages**. Contenuti in `_posts/` (blog post e progetti, ita/eng). Documentazione human-facing in `docs/`.

## Regole di lavoro (SEMPRE)

- **MAI `git push`** — lo fa sempre Allan. **Commit solo se richiesto esplicitamente.** MAI `Co-Authored-By` nei commit.
- **Validare dopo ogni modifica a `_posts/`**: `ruby scripts/validate_posts.rb` (front matter, date, riferimenti asset — no `bundle` richiesto). Gate del workflow `checks.yml` su ogni PR e del deploy.
- **Verifica link/immagini**: `rake test` (build + html-proofer, segnala 4xx) oppure `rake test_internal` (salta i link esterni). Non esiste linter né unit test — la validazione è l'html-proofer contro `_site/`. Su macOS/arm64 la fase sui link esterni può andare in **segfault dentro `ethon`/libcurl**: è l'ambiente, non il sito — usare `rake test_internal` e lasciare l'esterno alla CI.
- **Nuove feature = CI verde, senza rompere i gate esistenti**: prima di considerare completa una feature far passare i controlli che gireranno in CI — `ruby scripts/validate_posts.rb`, YAML-parse di config/workflow, JSON dei config, `rake test` se tocchi build/template. I gate sono `checks.yml` (validate + build + html-proofer) e `lighthouse.yml` (budget Lighthouse). Se il build locale non è eseguibile (serve Ruby 3.0/bundler), dirlo esplicitamente e lasciare la build a CI.
- **Documentare SEMPRE** modifiche a build, content model o workflow: allineare i `.md` in `docs/` (getting-started, writing-content, architecture, deployment) **senza chiederlo**. Ogni cambiamento fattuale va propagato a `docs/`, `_config.yml`, template, script.
- **Nuovi contenuti** solo come `_posts/YYYY-MM-DD-slug.markdown` con front matter corretto (vedi Content model sotto). `category: blog` → `/blog`; `category: project` + `projects: true` + `hidden: true` → `/projects`.
- **Service worker** (`sw.js`, alla radice perché lo scope non può salire): l'HTML è **sempre network-first** e il nome della cache **non** è versionato per build — il cron giornaliero svuoterebbe la cache offline di tutti ogni giorno. In cache solo font/icone (cache-first) e immagini (stale-while-revalidate); `search.json`, `feed.xml`, `sitemap.xml`, `robots.txt` mai. **Per disattivarlo non basta cancellare il file**: chi lo ha installato continua a usarlo — serve deployare un worker che fa `unregister()` (ricetta in testa a `sw.js`).
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

- **Git LFS**: i `.MOV` sotto `assets/video/` sono LFS-tracked e la checkout CI **non** scarica gli oggetti LFS → i video self-hosted arrivano al sito live come pointer file rotti. Nuovi video = **embed YouTube con la facade `<lite-youtube videoid="…">`** (non `<iframe>`, non file nel repo). La facade è `_includes/youtube-facade.html`.
- **Gli hook `_plugins` girano DUE VOLTE sui post**: registrando su `[:posts, :pages, :documents]` un post è sia `:post` sia `:document`, quindi `post_render` scatta due volte sullo stesso output. Ogni trasformazione va resa idempotente (`responsive_images.rb` fa matchare `<picture>…</picture>` prima di `<img>`, `lazy_images.rb` usa un lookahead negativo) — altrimenti si ottengono elementi annidati.
- **I `_plugins/` GIRANO**: il build è un `bundle exec jekyll build` completo in Actions (non la safe-mode di GH Pages), quindi i plugin custom in `_plugins/` vengono eseguiti (es. `lazy_images.rb` = lazy loading immagini). Sfruttabile per trasformazioni build-time.
- **Build locale richiede locale UTF-8**: senza `LANG=en_US.UTF-8` il Sass fallisce con `Invalid US-ASCII character`. Toolchain 3.0 via rbenv: `~/.rbenv/versions/3.0.7`.
- **Nessun branch `main`**: si lavora su `master`. Il deploy parte da push su `master`.
- **Ruby version**: il workflow `jekyll.yml` builda con **Ruby 3.0** / `JEKYLL_ENV=production`. Deve restare allineata a `Gemfile.lock`.
- **Paginazione `/blog` attiva** (`paginate: 10`): `jekyll-paginate` v1 conta anche i progetti `hidden`, quindi le pagine vecchie mostrano <10 item (dettaglio in `docs/architecture.md`).
- **Immagini nei post**: usare **URL relativi** per coerenza (vedi commit recenti).
- `_includes/style.scss` è l'entry point Sass che importa tutto da `_sass/` (`base/`, `components/`, `pages/`) ed è **l'unico file di stile processato da Liquid** (lì sta il `@font-face` che usa `{{ site.baseurl }}`).
- **Design token**: colori, spazi, raggi, motion e tipografia stanno in `_sass/base/tokens.scss` come custom properties su `:root`; `variables.sass` è solo un ponte (`$accent: var(--color-accent)`) per i partial storici. Mai hard-codare hex nei componenti. **Corollario**: sulle variabili della palette non si possono più usare le funzioni colore Sass (`darken()`, `rgba($var, …)`) — servono token dedicati (es. `--color-accent-soft`).
- **DUE TEMI** (scuro di default + chiaro): la palette sta in due mixin di `_sass/base/tokens.scss` (`palette-dark`, `palette-light`), applicati nell'ordine `:root` → `@media (prefers-color-scheme: light)` su `:root:not([data-theme="dark"])` → `:root[data-theme="…"]`. **L'ordine è sorgente, non specificità**: quei selettori pesano uguale, quindi i blocchi `[data-theme]` devono restare in fondo al file. Ogni colore nuovo va aggiunto a **entrambi** i mixin — se sta in uno solo smette di seguire il tema. Dopo ogni modifica ai colori: `ruby scripts/check_contrast.rb` (legge i mixin dal file, 52 coppie, soglia 6:1, fallisce anche sui token presenti in un solo tema). Lighthouse audita solo il tema con cui carica la pagina, quindi non copre l'altro.
- **Colori solo nei token**: `syntax.sass` non contiene più hex, mappa le classi Rouge sui `--syn-*`. Le velature non sono simmetriche (lo scuro schiarisce col bianco, il chiaro scurisce col nero): usare `--color-overlay-soft`, `--color-hover-overlay`, `--color-inset-line`, `--color-glass`, mai `rgba()` grezzi nei componenti.
- **Breakpoint**: `$mobile` ≤ 560px, `$tablet` 561–1050px (il 400px originale del tema lasciava fuori i telefoni da 390–430 CSS px).
- **Commenti Sass: `//`, non `/* */`** — il CSS è inlineato in ogni pagina e i `/* */` vengono emessi (oggi ~16 KB su ogni pagina), i `//` no. Vale solo nei file `_sass/`: negli script inline è l'opposto, vedi sotto.
- **Script inline: MAI commenti `//`** — `_layouts/compress.html` collassa le newline, quindi tutto ciò che segue `//` sulla riga collassata finisce commentato e lo script muore in silenzio. Usare `/* … */` (vale per `_includes/interactions.html` e `_includes/projects-filter.html`).
- **`hidden` va forzato**: i componenti dichiarano `display: block`, che vince sull'attributo. In `general.sass` c'è `[hidden] { display: none !important }` — non rimuoverlo, il filtro dei progetti dipende da quello.
- **`animation` è una proprietà sola**: due regole che animano lo stesso elemento si sostituiscono, non si sommano. Il titolo della home ne ha un caso (`.rotator` è anche `.em`): le animazioni vanno dichiarate insieme nella stessa `animation`.
- **Motion in `_sass/components/motion.scss`**, importato subito prima di `polish.sass` (che deve restare l'ultima parola su `prefers-reduced-motion`). Ogni animazione sta dietro `@supports`/`@media`: mai lasciare un elemento invisibile in attesa di un'animazione che potrebbe non partire.
- **Screenshot headless su macOS**: Chrome impone una finestra minima di ~500px, quindi `--window-size=390,…` ritaglia una pagina renderizzata a 500px e sembra overflow orizzontale. Testare il layout mobile a 500px, non sotto. Inoltre `--screenshot` **non cattura la pagina scrollata** (esce tutto nero): per verificare uno stato sotto la piega, usare una finestra molto alta (`--window-size=1000,3000`) oppure sondare il DOM con `--dump-dom` leggendo `getComputedStyle`.

## Deployment

Push su `master` → GitHub Pages via `.github/workflows/jekyll.yml` (push + cron giornaliero 10:00 UTC + dispatch manuale): build Ruby 3.0 / production, deploy dell'artifact `_site/`, poi job `smoke`: **checkfleet** sonda il sito **live** (target in `checkfleet.yml`) e allega il report Markdown al job summary — `checks.yml` valida `_site` *prima* del deploy, quindi è l'unico controllo su ciò che Pages serve davvero. `uptime.yml` fa girare lo stesso check ogni 10 minuti. `checks.yml` gira `validate_posts.rb` su ogni PR.

## Architettura

- `_config.yml` — identità sito, social, toggle feature (`projects`, `about`, `blog`, `read-time`, `show-tags`, `related`, `show-author`, `animation`, `width`).
- `_layouts/` — `default.html` (wrapper, estende `compress.html` per minify), `page.html`, `post.html`.
- `_includes/` — partial condivisi (nav, footer, author, related, analytics, social).
- Pagine top-level = template Liquid sottili: `index.html`, `blog/index.html`, `projects.html`, `tags.html`, `about.md`, `404.html`.
- `assets/images/` e `assets/video/` — media dei post; profilo in `assets/images/profile.jpg`.

## Puntatori

- Documentazione: `docs/` — `getting-started.md`, `writing-content.md`, `architecture.md`, `deployment.md`, `ROADMAP.md`.
- Script: `scripts/validate_posts.rb` (gate PR/deploy), `scripts/check_contrast.rb` (contrasto WCAG sui due temi, legge `tokens.scss`), `scripts/optimize_images.rb` (varianti WebP responsive, serve `cwebp`; le varianti si committano), `scripts/generate_pwa_icons.rb` (icone PWA da `scripts/pwa_icon.html`, serve Chrome), `scripts/sync_youtube.rb`, `scripts/sync_strava.rb`, `scripts/sync_github.rb` (repo GitHub → post progetto; crea i nuovi e **aggiorna** i post generati — marker `github:` — sui push del repo via campo `updated:`; config in `_data/github_sync.yml` con blocklist `exclude`), `scripts/sync_robots_sitemaps.rb` (repo Pages di Allan-Nava con `sitemap.xml` 200 → `_data/pages_sitemaps.yml`, che `robots.txt` renderizza; config in `_data/robots_sync.yml`), `scripts/backfill_youtube.rb` (one-shot: backfill intero canale YouTube), `scripts/migrate_youtube_embeds.rb` (one-shot: iframe→facade `<lite-youtube>`).
- Plugin build-time: `_plugins/lazy_images.rb` (lazy loading immagini), `_plugins/youtube_thumbnails.rb` (`image:` vuota + facade `<lite-youtube>` → thumbnail `i.ytimg.com`, 114 post), `_plugins/toc.rb` (riempie lo slot `toc-slot` di `post.html` con l'indice degli `h2`/`h3`, da 3 titoli in su). `_plugins/responsive_images.rb` (avvolge gli `<img>` locali in `<picture>` **solo se le varianti esistono su disco**; salta le thumbnail `.thumb` perché `home-blog-projects.sass` le stila con selettori a figlio diretto). Facade video: `_includes/youtube-facade.html`. Tema: `_includes/theme-init.html` (nel `<head>`, applica la scelta salvata **prima del primo paint**) + toggle cablato in `_includes/interactions.html`.
- Workflow CI: `.github/workflows/` — `jekyll.yml` (deploy), `checks.yml` (validazione PR), `lighthouse.yml` (budget Lighthouse su PR/push, config in `lighthouserc.json`), `youtube-sync.yml` (post automatici ogni 3h), `strava-sync.yml` (post da attività, richiede secret), `github-sync.yml` (repo → progetti, orario `29 * * * *`), `robots-sync.yml` (sitemap dei Pages live → `robots.txt`, giornaliero `0 4 * * *`), `uptime.yml` (probe checkfleet sul sito live ogni 10 min, target in `checkfleet.yml`), `bootstrap-milestone.yml` (one-shot issue/milestone).
- Pagine extra (toggle in `_config.yml`): `map.html` (`/map`, post con `lat`/`lng`), `fitness.html` (`/fitness`, dati in `_data/workouts.yml`), `gear.md` (`/gear`), `archive.html` (`/archive`), `stats.html` (`/stats`), `videos.html` (`/videos`), `search.html` + `search.json` (`/search`, indice generato a build time).
