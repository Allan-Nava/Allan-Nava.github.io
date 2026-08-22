# CLAUDE.md — allan-nava.github.io

Portfolio/blog personale di Allan Nava (`https://allan-nava.github.io`), costruito con **Jekyll** sul tema [Indigo](https://github.com/sergiokopplin/indigo) e deployato su **GitHub Pages**. Contenuti in `_posts/` (blog post e progetti, ita/eng). Documentazione human-facing in `docs/`.

## Regole di lavoro (SEMPRE)

- **MAI `git push`** — lo fa sempre Allan. **Commit solo se richiesto esplicitamente.** MAI `Co-Authored-By` nei commit.
- **Validare dopo ogni modifica a `_posts/`**: `ruby scripts/validate_posts.rb` (front matter, date, riferimenti asset — no `bundle` richiesto). Gate del workflow `checks.yml` su ogni PR e del deploy.
- **Verifica link/immagini**: `rake test` (build + html-proofer, segnala 4xx) oppure `rake test_internal` (salta i link esterni). Non esiste linter né unit test — la validazione è l'html-proofer contro `_site/`. La fase sui link esterni riporta ~1010 fallimenti su ~1440 link (link rot di dieci anni di post): è rumore atteso, per questo `checks.yml` controlla solo gli interni e `link-check.yml` apre una issue mensile. Il vecchio **segfault in `ethon`/libcurl** su macOS/arm64 non si riproduce con html-proofer 5, ma `ethon` è ancora nel bundle: se torna, usare `rake test_internal`.
- **Nuove feature = CI verde, senza rompere i gate esistenti**: prima di considerare completa una feature far passare i controlli che gireranno in CI — `ruby scripts/validate_posts.rb`, YAML-parse di config/workflow, JSON dei config, `rake test` se tocchi build/template. I gate sono `checks.yml` (validate + build + html-proofer) e `lighthouse.yml` (budget Lighthouse). Se il build locale non è eseguibile, dirlo esplicitamente e lasciare la build a CI.
- **Documentare SEMPRE** modifiche a build, content model o workflow: allineare i `.md` in `docs/` (getting-started, writing-content, architecture, deployment) **senza chiederlo**. Ogni cambiamento fattuale va propagato a `docs/`, `_config.yml`, template, script.
- **Nuovi contenuti** solo come `_posts/YYYY-MM-DD-slug.markdown` con front matter corretto (vedi Content model sotto). `category: blog` → `/blog`; `category: project` + `projects: true` + `hidden: true` → `/projects`.
- **Rilevare un binario: MAI `system('command', '-v', nome)` in forma ad array** — `command` è un builtin di shell e su Ubuntu non esiste come eseguibile, mentre su macOS `/usr/bin/command` c'è davvero: il controllo passa in locale e fallisce in CI. Ha ucciso `image-optimize.yml` con "Chrome non trovato" pur avendo Chrome installato. Usare la `which()` in Ruby puro che sta in `scripts/generate_og_cards.rb` (cerca nel PATH a mano), e tenere nei candidati anche i percorsi assoluti Linux (`/usr/bin/google-chrome`, …).
- **giscus**: `repo-id`/`category-id` in `_config.yml` sono **node id GraphQL**, non valori da giscus.app — si rileggono con `gh api repos/:owner/:repo --jq .node_id` e una query GraphQL su `discussionCategories`. L'include costruisce lo `<script>` in JS perché `data-theme` deve seguire i due temi del sito e va deciso **prima** che l'iframe esista (dopo si cambia solo via `postMessage`).
- **Analytics**: `analytics-google: 'G-X841VQSHB8'` — GA4 attivo da agosto 2026 (proprietà "Allan Nava github pages - GA4", flusso web 5725926646); si spegne ricommentando la chiave. L'include non è lo snippet gtag standard — costruisce il tag da sé per poter **non** caricarlo: salta localhost/127.0.0.1 (niente statistiche da `jekyll serve`, Lighthouse CI e smoke test) e rispetta DNT/GPC. Attivarlo non tocca i punteggi Lighthouse (misurato).
- **`image: ""` è TRUTHY per `jekyll-seo-tag`**: la risolve come URL relativo ed emette `og:image` = URL del sito, cioè un'anteprima rotta (succedeva a 201 post progetto, con due `og:image` in pagina e gli scraper che leggono il primo). `_plugins/og_image.rb` cancella la chiave vuota prima del render e, se esiste, assegna la card per-post in **`page.og_card`** — mai in `page.image`, che è anche la thumbnail dei listing e sostituirebbe i placeholder generativi con card da 1200x630.
- **Service worker** (`sw.js`, alla radice perché lo scope non può salire): l'HTML è **sempre network-first** e il nome della cache **non** è versionato per build — il cron giornaliero svuoterebbe la cache offline di tutti ogni giorno. In cache solo font/icone (cache-first) e immagini (stale-while-revalidate); `search.json`, `feed.xml`, `sitemap.xml`, `robots.txt` mai. **Per disattivarlo non basta cancellare il file**: chi lo ha installato continua a usarlo — serve deployare un worker che fa `unregister()` (ricetta in testa a `sw.js`).
- **Anteprime YouTube**: `hqdefault.jpg` è sempre 480x360 — nei 16:9 il frame sta fra due bande nere da 45px, nei verticali fra due pannelli sfocati messi da YouTube. Nel box **16:9** `object-fit: cover` ritaglia esattamente le bande (nessuno zoom serve: uno `scale(1.3334)` lì è un sovra-ritaglio del 33%); nel box **quadrato** di mobile le bande restano, e lì il 4/3 di zoom è l'unica cosa che le toglie. I video verticali hanno `thumb:` = `oardefault.jpg` (formato originale) e box verticale — `oardefault` esiste **solo** se il video non è 16:9, quindi la sua presenza è il segnale dell'orientamento, meglio del tag `short` (sbaglia 4 volte su 133). `image:` resta l'hqdefault: è anche l'`og:image` (#163).
- **Feed**: `jekyll-feed` non c'è più (#160) — non sa escludere i post `hidden: true`, e i progetti generati da `sync_github.rb` occupavano metà di `/feed.xml`. I due feed sono template a mano nella radice: `feed.xml` (blog) e `feed-projects.xml` → `/projects/feed.xml`. Due regole: `<content>` sta in CDATA e **non** va passato a `xml_escape` (le entità escapate si vedono letterali), e `strip_html` sul corpo di un post video non lascia niente — il summary viene dalla `description`. Nessun plugin li rigenera: sono in `checkfleet.yml`.
- **`<head>` / SEO**: il `<title>` lo compone **`_layouts/default.html`**, non il plugin — la chiamata è `{% seo title=false %}`. Motivo: seo-tag fa `"{page.title} | {site.title}"` e in home dava **"Home | Allan Nava"**. Il `title:` della home è ora **`Allan Nava`** perché `og:title` seo-tag lo prende SOLO da `page.title` (nessun override possibile): chi si appoggiava a quella stringa è stato slegato — `_includes/header.html` guarda `page.url == "/"`, e la classe del wrapper usa `slugify`, non `downcase`. **Mai** riaggiungere `<meta name=description>` o `<link rel=canonical>` a mano nel layout: li emette seo-tag, e i duplicati (tema + plugin) erano il bug. `site.description` non deve mai tornare vuota: è il fallback di ogni pagina senza `description:` propria. `twitter` in `_config.yml` è **annidata** (`twitter.username`) perché seo-tag legge solo quella — piatta emetteva `twitter:site` = `@`.
- **Lingua per pagina**: `<html lang>` in `_layouts/default.html` era cablato a `en` su tutto il sito, che e' in gran parte italiano. Ora viene da `page.lang` (fallback `site.lang`, poi `en`), e `og:locale` da `locale:` nel front matter — i post nuovi in italiano vogliono `lang: it` + `locale: it_IT`. Le pagine senza le due chiavi restano `en` come prima. **`twitter:card` resta `summary`** per tutti i post: lo emette seo-tag e diventa `summary_large_image` solo se la pagina ha `image:`, che noi teniamo vuota di proposito (la card 1200x630 sta in `page.og_card`). Su X l'anteprima e' quindi piccola: per cambiarlo serve smettere di far emettere quel meta a seo-tag, non aggiungerne un secondo.
- **`checkfleet.yml` asserisce i `<title>` del sito live**: cambiare il titolo di una pagina e non aggiornare il target fa risultare il sito **giu'** (smoke post-deploy + uptime ogni 10 min) mentre risponde 200 — successo col titolo della home. La home e' l'unico target che asserisce un **prefisso** (`<title>Allan Nava — `), perche' la tagline e' copy: le altre pagine sono `"{page.title} | {site.title}"`, stabili.
- **Search Console**: `google_site_verification` in `_config.yml` è il token della proprietà `https://allan-nava.github.io/`; il `<meta>` lo stampa `jekyll-seo-tag` su tutte le pagine — non aggiungerlo a mano al layout. **Non toglierlo dopo la verifica**: Google ricontrolla il tag e senza la proprietà torna non verificata (via i dati e la richiesta di indicizzazione).
- **Identità (`sameAs`)**: `_includes/schema-person.html` (JSON-LD Person + WebSite) è incluso **solo su `/` e `/about/`**; i profili vengono da `social.links` in `_config.yml`, mai hard-codati, e sono linkati con `rel="me"` in `social-links.html`. Il JSON è scritto **con uno spazio dopo ogni due punti**: serve a non far mai combaciare il pattern `:shortcode:` di jemoji, che gira anche dentro gli `<script>`. La metà del lavoro che non sta nel repo è il link **di ritorno** dai profili al sito (campo Website di GitHub — oggi punta a LinkedIn —, LinkedIn, About di YouTube).
- **Tag: una sola scrittura per argomento** — `iOS` e `ios` per Jekyll sono tag diversi ma hanno lo stesso slug, quindi generano due chip e due archivi con meta' dei post ciascuno. `validate_posts.rb` avvisa quando due tag collidono sullo slug; per unificarli c'e' `scripts/consolidate_tags.rb` (canonica: la variante gia' uguale al proprio slug, altrimenti la piu' usata).
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
- **I `_plugins/` girano anche sul sito pubblicato**: Pages e' su `build_type: workflow` (verificato con `gh api repos/:owner/:repo/pages`), quindi a pubblicare e' l'artifact di `jekyll.yml`, costruito con `bundle exec jekyll build` completo. Riscontro sul live: `/projects/` serve 158 `thumb-placeholder`, che li genera un filtro Liquid di `_plugins/card_placeholder.rb`. **Non era vero fino a #144**, quando Pages stava su `build_type: legacy` e il builder safe-mode di GitHub ignorava i `_plugins/`: se una feature costruita su un plugin non si vede sul live, ricontrollare prima di tutto quel campo.
- **Build locale richiede locale UTF-8**: senza `LANG=en_US.UTF-8` il Sass fallisce con `Invalid US-ASCII character`. Il toolchain locale è **3.3.12** (`.ruby-version` nel repo, `~/.rbenv/versions/3.3.12`), la stessa minor della CI. **Non basta una 3.0**: `html-proofer ~> 5.0` richiede Ruby ≥ 3.1, quindi con la 3.0.7 `bundle install` non passa e il build muore con `Bundler::GemNotFound`.
- **Nessun branch `main`**: si lavora su `master`. Il deploy parte da push su `master`.
- **La data di un post nuovo va nel passato in UTC**: `_config.yml` non imposta `timezone`, quindi in CI la
  data del front matter e' letta come **UTC**, e con `future: false` (default di Jekyll) un post ancora futuro
  viene **scartato in silenzio** — build verde, deploy success, pagina 404 e nessuna card in `/projects`.
  In locale non si vede perche' il fuso e' CEST (+02:00): un post datato `00:30` esiste in locale e non esiste
  in CI. Per verificare come la CI: `TZ=UTC bundle exec jekyll build`, poi cercare il file in `_site/`.
- **Ruby version**: i workflow buildano con **Ruby 3.3** / `JEKYLL_ENV=production`, con `ruby/setup-ruby` pinnato per SHA (la versione precedente non conosceva la 3.3) e `BUNDLED WITH 2.4.22` nel lock — `setup-ruby` installa il bundler del lock, e il 2.1.4 di prima su 3.3 non regge.
- **Stack gem (#128)**: `github-pages` **232** (Jekyll 3.10, kramdown 2.4), `html-proofer` **5.x** pinnato `~> 5.0` (nokogiri 1.19). Due vincoli scoperti misurando: html-proofer **3.x va in segfault** col nokogiri di gh-pages 232, e html-proofer **5.x richiede Ruby ≥ 3.1** — quindi 5.x e il bump di Ruby sono un passo unico, non due. I flag CLI (uguali fra 4 e 5) sono rinominati rispetto alla 3.x: `--ignore-urls`, `--ignore-empty-alt`, `--assume-extension ".html"`, `--ignore-status-codes`. Tenere allineati `Rakefile`, `checks.yml` e `link-check.yml`. **Nel Rakefile passare sempre una copia delle opzioni** (`.dup`/`.merge`): html-proofer 5 modifica l'hash ricevuto, e `PROOFER_OPTIONS` è `freeze`d — passarlo diretto dà `FrozenError`.
- **Paginazione `/blog` attiva** (`paginate: 10`): `jekyll-paginate` v1 conta anche i progetti `hidden`, quindi le pagine vecchie mostrano <10 item (dettaglio in `docs/architecture.md`).
- **Immagini nei post**: usare **URL relativi** per coerenza (vedi commit recenti).
- `_includes/style.scss` è l'entry point Sass che importa tutto da `_sass/` (`base/`, `components/`, `pages/`) ed è **l'unico file di stile processato da Liquid** (lì sta il `@font-face` che usa `{{ site.baseurl }}`).
- **Design token**: colori, spazi, raggi, motion e tipografia stanno in `_sass/base/tokens.scss` come custom properties su `:root`; `variables.sass` è solo un ponte (`$accent: var(--color-accent)`) per i partial storici. Mai hard-codare hex nei componenti. **Corollario**: sulle variabili della palette non si possono più usare le funzioni colore Sass (`darken()`, `rgba($var, …)`) — servono token dedicati (es. `--color-accent-soft`).
- **DUE TEMI** (scuro di default + chiaro): la palette sta in due mixin di `_sass/base/tokens.scss` (`palette-dark`, `palette-light`), applicati nell'ordine `:root` → `@media (prefers-color-scheme: light)` su `:root:not([data-theme="dark"])` → `:root[data-theme="…"]`. **L'ordine è sorgente, non specificità**: quei selettori pesano uguale, quindi i blocchi `[data-theme]` devono restare in fondo al file. Ogni colore nuovo va aggiunto a **entrambi** i mixin — se sta in uno solo smette di seguire il tema. Dopo ogni modifica ai colori: `ruby scripts/check_contrast.rb` (legge i mixin dal file, 52 coppie, soglia 6:1, fallisce anche sui token presenti in un solo tema). Lighthouse audita solo il tema con cui carica la pagina, quindi non copre l'altro.
- **Colori solo nei token**: `syntax.sass` non contiene più hex, mappa le classi Rouge sui `--syn-*`. Le velature non sono simmetriche (lo scuro schiarisce col bianco, il chiaro scurisce col nero): usare `--color-overlay-soft`, `--color-hover-overlay`, `--color-inset-line`, `--color-glass`, mai `rgba()` grezzi nei componenti.
- **Breakpoint**: `$mobile` ≤ 560px, `$tablet` 561–1050px (il 400px originale del tema lasciava fuori i telefoni da 390–430 CSS px).
- **Commenti Sass: `//`, non `/* */`** — il CSS è inlineato in ogni pagina e i `/* */` vengono emessi (oggi ~16 KB su ogni pagina), i `//` no. Vale solo nei file `_sass/`: negli script inline è l'opposto, vedi sotto.
- **`jemoji` entra anche negli `<script>`**: gira dopo Liquid sull'HTML finito e ignora solo `pre`/`code`/`tt` (la pipeline è cablata nel gem 0.12.0, non c'è opzione per aggiungere `script`). Basta **un** shortcode tipo `:video_camera:` nella pagina — e 10 post ce l'hanno nel titolo — e succedono due cose: lo shortcode dentro una stringa JS diventa `<img class="emoji" …>` e le virgolette rompono la stringa (*Unexpected identifier*, pagina morta); inoltre jemoji ri-parsa e ri-serializza **tutto** il documento con Nokogiri, che scambia per markup le stringhe HTML dentro il JS e ne riscrive gli attributi (`'<a href="' + s.url` → `'<a href="'%20+%20s.url`). Ha ucciso `/map`. Contromisure in `map.html`: titoli passati con `| replace: ":", "\u003a"` (in JS vale `:` ma non fa scattare il pattern, quindi il documento non viene nemmeno ri-parsato) e popup costruiti con il DOM invece che concatenando HTML.
- **Script inline: MAI commenti `//`** — `_layouts/compress.html` collassa le newline, quindi tutto ciò che segue `//` sulla riga collassata finisce commentato e lo script muore in silenzio. Usare `/* … */` (vale per `_includes/interactions.html` e `_includes/projects-filter.html`).
- **`data-count` è già preso**: il conteggio animato della home in `interactions.html` **sostituisce il contenuto** di ciò che seleziona. Selezionava `[data-count]` senza altri vincoli e ha svuotato la galleria dei post (#154), che usava lo stesso attributo per il numero di foto, lasciandoci dentro solo la cifra. Ora il selettore è `.stat-value[data-count]` e la galleria usa `data-photos`: tenere gli attributi dati aderenti al componente, mai generici.
- **`hidden` va forzato**: i componenti dichiarano `display: block`, che vince sull'attributo. In `general.sass` c'è `[hidden] { display: none !important }` — non rimuoverlo, il filtro dei progetti dipende da quello.
- **`animation` è una proprietà sola**: due regole che animano lo stesso elemento si sostituiscono, non si sommano. Il titolo della home ne ha un caso (`.rotator` è anche `.em`): le animazioni vanno dichiarate insieme nella stessa `animation`.
- **Motion in `_sass/components/motion.scss`**, importato subito prima di `polish.sass` (che deve restare l'ultima parola su `prefers-reduced-motion`). Ogni animazione sta dietro `@supports`/`@media`: mai lasciare un elemento invisibile in attesa di un'animazione che potrebbe non partire.
- **Screenshot headless su macOS**: Chrome impone una finestra minima di ~500px, quindi `--window-size=390,…` ritaglia una pagina renderizzata a 500px e sembra overflow orizzontale. Testare il layout mobile a 500px, non sotto. Inoltre `--screenshot` **non cattura la pagina scrollata** (esce tutto nero): per verificare uno stato sotto la piega, usare una finestra molto alta (`--window-size=1000,3000`) oppure sondare il DOM con `--dump-dom` leggendo `getComputedStyle`.

## Deployment

Push su `master` → GitHub Pages via `.github/workflows/jekyll.yml` (push + cron giornaliero 10:00 UTC + dispatch manuale): build Ruby 3.3 / production, deploy dell'artifact `_site/`, poi job `smoke`: **checkfleet** sonda il sito **live** (target in `checkfleet.yml`, 3 tentativi a 20s — subito dopo il deploy la CDN può rispondere 5xx, e un 503 è un finding BAD che `retries:` non ritenta) e allega il report Markdown al job summary — `checks.yml` valida `_site` *prima* del deploy, quindi è l'unico controllo su ciò che Pages serve davvero. `uptime.yml` fa girare lo stesso check ogni 10 minuti. `checks.yml` gira `validate_posts.rb` su ogni PR.

## Architettura

- `_config.yml` — identità sito, social, toggle feature (`projects`, `about`, `blog`, `read-time`, `show-tags`, `related`, `show-author`, `animation`, `width`).
- `_layouts/` — `default.html` (wrapper, estende `compress.html` per minify), `page.html`, `post.html`.
- `_includes/` — partial condivisi (nav, footer, author, related, analytics, social).
- Pagine top-level = template Liquid sottili: `index.html`, `blog/index.html`, `projects.html`, `tags.html`, `about.md`, `404.html`.
- `assets/images/` e `assets/video/` — media dei post; profilo in `assets/images/profile.jpg`.

## Puntatori

- Documentazione: `docs/` — `getting-started.md`, `writing-content.md`, `architecture.md`, `deployment.md`, `ROADMAP.md`.
- Script: `scripts/validate_posts.rb` (gate PR/deploy), `scripts/check_contrast.rb` (contrasto WCAG sui due temi, legge `tokens.scss`), `scripts/optimize_images.rb` (varianti WebP+AVIF responsive, servono `cwebp` e `ffmpeg`; le varianti si committano), `scripts/generate_pwa_icons.rb` (icone PWA da `scripts/pwa_icon.html`, serve Chrome), `scripts/generate_og_cards.rb` (card social per-post in `assets/images/og/`, JPEG, serve Chrome), `scripts/sync_youtube.rb`, `scripts/sync_strava.rb`, `scripts/sync_github.rb` (repo GitHub → post progetto; crea i nuovi e **aggiorna** i post generati — marker `github:` — sui push del repo via campo `updated:`; config in `_data/github_sync.yml` con blocklist `exclude`), `scripts/resync_locations.rb` (località YouTube nei post **già pubblicati** → `lat`/`lng`, girato dal workflow youtube-sync; `DRY_RUN=1`, `REFRESH=1`), `scripts/sync_robots_sitemaps.rb` (repo Pages di Allan-Nava con `sitemap.xml` 200 → `_data/pages_sitemaps.yml`, che `robots.txt` renderizza; config in `_data/robots_sync.yml`), `scripts/backfill_youtube.rb` (one-shot: backfill intero canale YouTube), `scripts/migrate_youtube_embeds.rb` (one-shot: iframe→facade `<lite-youtube>`), `scripts/sync_youtube_thumbs.rb` (anteprime formato originale dei video verticali → `thumb:`, girato dal workflow youtube-sync; `DRY_RUN=1`, `FULL=1`), `scripts/dedupe_title_heading.rb` (one-shot: toglie dal corpo il primo heading che ripete il titolo — 259 post; `validate_posts.rb` ora avvisa se ricompare).
- Plugin build-time: `_plugins/lazy_images.rb` (lazy loading immagini), `_plugins/youtube_thumbnails.rb` (`image:` vuota + facade `<lite-youtube>` → thumbnail `i.ytimg.com`, 114 post), `_plugins/toc.rb` (riempie lo slot `toc-slot` di `post.html` con l'indice degli `h2`/`h3`, da 3 titoli in su). `_plugins/responsive_images.rb` (avvolge gli `<img>` locali in `<picture>` **solo se le varianti esistono su disco**; salta le thumbnail `.thumb` perché `home-blog-projects.sass` le stila con selettori a figlio diretto), `_plugins/photo_gallery.rb` (≥2 immagini consecutive → `<div class="gallery" data-photos="N">`, 22 post/76 foto; riconosce il blocco sia con sia senza `<picture>`, quindi non dipende dall'ordine di caricamento). Facade video: `_includes/youtube-facade.html`; lightbox: `_includes/lightbox.html` (incluso solo sui post). Tema: `_includes/theme-init.html` (nel `<head>`, applica la scelta salvata **prima del primo paint**) + toggle cablato in `_includes/interactions.html`.
- Workflow CI: `.github/workflows/` — `jekyll.yml` (deploy), `checks.yml` (validazione PR), `lighthouse.yml` (budget Lighthouse su PR/push, config in `lighthouserc.json`), `youtube-sync.yml` (post automatici ogni 3h), `strava-sync.yml` (post da attività, richiede secret), `github-sync.yml` (repo → progetti, orario `29 * * * *`), `robots-sync.yml` (sitemap dei Pages live → `robots.txt`, giornaliero `0 4 * * *`), `uptime.yml` (probe checkfleet sul sito live ogni 10 min, target in `checkfleet.yml`), `bootstrap-milestone.yml` (one-shot issue/milestone).
- Pagine extra (toggle in `_config.yml`): `map.html` (`/map`, post con `lat`/`lng`), `fitness.html` (`/fitness`, dati in `_data/workouts.yml`), `gear.md` (`/gear`), `archive.html` (`/archive`), `stats.html` (`/stats`), `videos.html` (`/videos`), `search.html` + `search.json` (`/search`, indice generato a build time).
