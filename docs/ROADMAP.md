# Roadmap — Backlog versionato

Il backlog del sito, organizzato in milestone versionate: la versione è assegnata per priorità/dipendenze (v2.0 prima, v3.0 dopo). Ogni voce diventa una issue GitHub nella milestone corrispondente: le crea `bootstrap-milestone.yml` (Actions → "Bootstrap milestone" → Run workflow, idempotente — rilanciarlo dopo aver aggiunto voci qui e nel workflow crea solo le nuove).

## v2.0 — Performance & Navigazione ✅ (quasi completa)

Urgente dopo il backfill YouTube: 218 file in `_posts/` (172 blog + 46 progetti). Implementata e validata con `rake test` su Ruby 3.0.7.

- [x] **Paginazione di `/blog`** — `paginate: 10` + `paginate_path: "blog/:num/"` (plugin `jekyll-paginate`), 19 pagine. Caveat noto: v1 conta anche i progetti `hidden`, quindi le pagine più vecchie (2019) mostrano <10 item — vedi `docs/architecture.md`.
- [x] **Facade per gli embed YouTube (lite-youtube)** — `_includes/youtube-facade.html` (custom element self-contained, no CDN): thumbnail cliccabile, player `youtube-nocookie` solo al click. Generatori aggiornati + `scripts/migrate_youtube_embeds.rb` ha convertito 114 post (137 iframe).
- [x] **Lazy loading immagini** — plugin build-time `_plugins/lazy_images.rb` (`loading="lazy"` + decoding async su tutte le img di contenuto; salta gli hero LCP `title-image`/`selfie`).
- [x] **Thumbnail nei post auto-generati da YouTube** — `sync_youtube.rb`/`backfill_youtube.rb` impostano `image:` = `https://i.ytimg.com/vi/<id>/hqdefault.jpg` (listing + og:image).
- [x] **Badge di stato nel README** — badge Deploy / Checks / Uptime.
- [ ] **Disinstallare Renovate** — *manuale* (Settings → Integrations, poi chiudere le sue PR/issue #25, #43): l'app duplica Dependabot. Non automatizzabile da repo.

## v2.1 — Contenuti & Engagement

- [ ] **Pagina statistiche `/stats`** — post per anno, tag più usati, totali; tutto in Liquid a build time.
- [ ] **Pagina archivio per anno `/archive`** — post raggruppati per anno, Liquid puro.
- [ ] **Ricerca client-side** — indice `search.json` generato da Liquid + pagina `/search` con fuzzy match in vanilla JS; con 200+ post serve.
- [ ] **Related posts per tag** — il box "related" mostra i post più recenti, non i più affini: sostituirlo con un match sui tag condivisi.
- [ ] **Serie di post** — campo `series:` nel front matter + box "puntata N di M" con navigazione (es. Flutter Italia Espresso).
- [ ] **Galleria video `/videos`** — griglia delle thumbnail di tutti i post YouTube (dipende dalle thumbnail in v2.0).
- [ ] **404 intelligente** — link utili + ultimi post nella pagina 404.
- [ ] **Copy-code button** — bottone "copia" sui blocchi di codice dei post tech.
- [ ] **Reading progress + scroll-to-top** — barra di avanzamento lettura e bottone per risalire.
- [ ] **Commenti con giscus** — GitHub Discussions come sistema di commenti, toggle in `_config.yml`.
- [ ] **Analytics GA4 o privacy-friendly** — property GA4 (`G-XXXX` in `_config.yml`, include gtag già pronto) oppure GoatCounter/Plausible.

## v2.2 — Automazioni & Platform

- [ ] **Modernizzazione stack Ruby** — in sequenza: merge PR `github-pages` 211→223→232 (Jekyll 3.10), bump Ruby 3.3 nei workflow e unpin di `setup-ruby`, poi `html-proofer` 5.x adattando `Rakefile` e i flag in `checks.yml`.
- [ ] **Sync YouTube v2** — descrizione completa del video nel body; coordinate GPS dalla descrizione YouTube (formato `📍 lat, lng`) → post geolocalizzato e marker su `/map` automatico.
- [ ] **Setup secret Strava** — creare l'app API e configurare `STRAVA_*` nei secret (guida in `deployment.md`) per attivare `strava-sync.yml`.
- [ ] **Auto-issue sui fallimenti dei cron** — step `if: failure()` nei workflow schedulati che apre/aggiorna una issue col link al run fallito.
- [ ] **Link checker mensile** — workflow schedulato con html-proofer sui link esterni che apre/aggiorna una issue con l'elenco dei morti (senza far fallire la CI).
- [ ] **OG image automatica** — immagine social generata per i post senza `image:`.
- [ ] **Newsletter RSS-to-email** — Buttondown/Mailchimp sul `/feed.xml` esistente + form di iscrizione nel footer.
- [ ] **Webmentions** — like/repost/commenti da Mastodon/Bluesky via brid.gy + webmention.io.

## v2.3 — Design & UI (restyling del template) ✅

Restyling grafico del tema Indigo, che era rimasto quello originale (pensato per sfondo chiaro) con sopra le pezze di `_sass/components/polish.sass`. Fatto nell'ordine giusto: **token e tipografia prima**, componenti dopo — le fondamenta valgono anche per il light mode di v3.0. Verificato con build Ruby 3.0.7, html-proofer interno (359 file, 0 failure) e Lighthouse locale: **performance 99–100, accessibility 100, best-practices 100, SEO 100** sulle pagine strutturali (`/tags` a 92 di performance per il peso della pagina).

- [x] **Design token in CSS custom properties** — `_sass/base/tokens.scss`: `--color-*`, `--space-*`, `--radius-*`, `--dur-*`/`--ease-*`, `--text-*`, `--measure`/`--width-*`. `variables.sass` resta come alias (`$accent: var(--color-accent)`) per non riscrivere i partial storici. NB: da qui in poi le funzioni colore Sass (`darken()`, `rgba($var,…)`) non sono più applicabili alla palette — servono token dedicati (`--color-accent-soft`).
- [x] **Scala tipografica fluida + font self-hosted** — Inter variabile (subset latin, **47 KB**) in `assets/fonts/`, `@font-face` in `_includes/style.scss` (unico file processato da Liquid → `{{ site.baseurl }}`) con `font-display: swap` e preload in `default.html`; scale `--text-*` con `clamp()`, corpo dei post limitato a `--measure` (68ch).
- [x] **Tema scuro per `code`/`pre` e syntax highlighting** — `syntax.sass` riscritto su palette scura (commenti, keyword, stringhe, tipi in verde per legarsi all'accento); inline `code` come chip verde su `--color-accent-soft`. Niente più slab bianchi nei post tech.
- [x] **Listing a card con thumbnail** — `/blog` e `/projects` sono card (titolo, descrizione a 2 righe, meta) con thumbnail quando c'è `image:`. Il nuovo `_plugins/youtube_thumbnails.rb` ricava la thumbnail dal `videoid` della facade per **114 post video** che avevano `image: ""` (vale anche per `og:image`).
- [x] **Nav sticky + menu mobile** — `_includes/nav.html` renderizzata da `default.html` fuori dal wrapper: barra sticky con `backdrop-filter`, brand, **stato attivo** sulla pagina corrente (prima la voce corrente veniva nascosta) e riga di link che scorre su mobile, senza JS. Aggiunti skip-link e `<main>`.
- [x] **Restyling hero della home** — griglia avatar+testo, titolo, bio, CTA "Read the blog"/"Browse projects" e social; su Blog/Projects/Tags intestazione compatta con sottotitolo.
- [x] **Header dei post ridisegnato** — `.post-article`/`.post-header` (classi sull'article, non più dipendenti da `page.tag`), hero image full-width, riga meta compatta (data · updated · reading time) e chip tag.
- [x] **Indice dei contenuti nei post lunghi** — `_plugins/toc.rb` riempie lo slot di `post.html` con un `<details open>` degli `h2`/`h3` (soglia: 3 titoli, quindi oggi non compare su nessun post — è per gli articoli lunghi). Legge gli `id` di kramdown: nessuna dipendenza da Nokogiri.
- [x] **Footer a colonne** — about · site · elsewhere + riga finale con copyright e crediti tema.
- [x] **Micro-interazioni + `prefers-reduced-motion`** — durate/easing dai token, hover/focus uniformi, blocco di `@media (prefers-reduced-motion: reduce)` che azzera animazioni, transizioni e `scroll-behavior`.
- [x] **Contrasto AA e promozione dei gate Lighthouse** — tutte le coppie della palette ≥ 6:1 (minimo: commenti del codice 6.1:1). Corretti gli audit che restavano rossi (nome accessibile del brand e dei social link, `<main>` mancante, salto `h1`→`h3` nelle card) → accessibility 100. In `lighthouserc.json`: accessibility e best-practices da `warn` a **error** (0.95), SEO error 0.90, performance warn 0.85.

Extra emersi durante il lavoro: `name:` mancante in `_config.yml` (hero, brand e footer stampavano una stringa vuota), breakpoint `$mobile` spostato da 400px a **560px** (i telefoni stanno fra 390 e 430 CSS px e finivano nel layout tablet), `Rakefile` allineato ai flag di `checks.yml` + task `rake test_internal`.

## v2.4 — Motion & visual polish (il sito che si muove) ✅

Secondo giro di design, dopo le fondamenta di v2.3. Rilasciato come **v2.1.0**. Ogni effetto è progressive enhancement: dietro `@supports`/`@media`, quindi dove il browser non conosce la tecnica l'elemento è già al suo posto, mai invisibile. Gate finali: **accessibility 100, best-practices 100, SEO 100** ovunque, performance 99–100 (`/tags` 91).

- [x] **Placeholder generativo per le card senza thumbnail** — `_plugins/card_placeholder.rb`: monogramma su gradiente da un hash **stabile** del titolo (non `Object#hash`, randomizzato per processo), 6 palette. Copre 112 card di progetto.
- [x] **Reveal delle card allo scroll** — `animation-timeline: view()`, niente JS. **Escluso `/tags`**: animare le migliaia di righe di quella pagina costa ~5 punti di performance (86 → 91 togliendolo).
- [x] **View Transitions fra le pagine** — `@view-transition` + nome dedicato alla nav (che resta ferma); il JS assegna `card-image`/`card-title` alla card cliccata, che il post ritrova sull'header.
- [x] **Nav che reagisce allo scroll** — `animation-timeline: scroll()` su ombra e bordo: l'altezza non si tocca, altrimenti il contenuto salta.
- [x] **Hero animato** — alone radiale in movimento dietro l'avatar ed entrata a cascata di titolo, bio, CTA, numeri e social.
- [x] **Filtri dinamici su /projects** — chip dei 12 tag più usati (`_plugins/project_tags.rb`, conteggio **per slug e per post** così il numero sul chip è esattamente quello dei risultati), filtro client-side e contatore. Senza JS i chip non compaiono e la lista resta intera.
- [x] **Micro-interazioni su link e bottoni** — underline che cresce sui link dei post, `:active` percepibile, freccia `↗` che scatta.
- [x] **Fade-in delle immagini al caricamento** — l'opacità iniziale a 0 è attivata solo dalla classe `js`, così senza JavaScript le thumbnail non spariscono.
- [x] **Hover spotlight sulle card** — `--mx`/`--my` aggiornate dal puntatore, spento sotto i 561px e con reduced-motion.
- [x] **Numeri animati sulla home** — 176 post, 154 progetti, 118 video, 290 tag: contati in Liquid, animati dal JS, già corretti nell'HTML se il JS non parte.
- [x] **Tipografia display per hero e titoli** — peso 800 e tracking più stretto sullo stesso file variabile: nessuna richiesta di rete in più.

Due trappole trovate durante il lavoro, ora documentate: i commenti `//` negli script inline vengono **mangiati da `compress.html`** (che collassa le newline), e l'attributo `hidden` non nasconde nulla dove un componente dichiara `display: block`.

## v3.0 — Big rocks

- [ ] **Migrazione video LFS → YouTube** — caricare su YouTube i ~39 `.MOV` (`assets/video/`, serviti via `github.com/raw` con quota banda LFS 1 GB/mese), sostituire gli embed, rimuovere `assets/video/` (−700 MB). Opzionale: BFG sulla history (force-push, per ultima).
- [ ] **Light mode / toggle tema** — il tema è già **scuro** (`$background: #050505` in `_sass/base/variables.sass`); manca una palette chiara e un toggle `prefers-color-scheme`. **Dipende dai design token di v2.3**: con i colori esposti come custom properties il light mode è una ridefinizione di `:root`, senza token va riscritto ogni file `.sass`. NB: essendo scuro, ogni nuovo stile va verificato per contrasto (es. `strong`/`code` avevano colori pensati per sfondo chiaro → testo invisibile, corretto).
- [ ] **Ottimizzazione immagini automatica** — WebP/AVIF con fallback, `srcset` responsivo, job CI che comprime le immagini nuove sopra soglia.
- [ ] **PWA** — manifest + service worker: sito installabile e leggibile offline.

## ✅ Fatte

- [x] **Mappa delle escursioni** — `/map` con Leaflet; post con `lat`/`lng` → marker (15 post geolocalizzati al lancio).
- [x] **Fitness tracker** — `/fitness` con tabelle e grafici SVG dei PR, dati in `_data/workouts.yml`.
- [x] **Strava sync** — `strava-sync.yml` + `scripts/sync_strava.rb` (in attesa dei secret, vedi v2.2).
- [x] **Pagina gear** — `/gear` (voci placeholder da compilare).
- [x] **YouTube sync + backfill completo** — `youtube-sync.yml` ogni 3h + `scripts/backfill_youtube.rb` (intero canale, 95 post generati).
- [x] **CI di validazione** — `checks.yml` (validator + build + html-proofer) su PR e push; validator come gate del deploy.
- [x] **Lighthouse CI** — `lighthouse.yml` + `lighthouserc.json`: build → serve locale → Lighthouse sulle pagine strutturali, su PR e push. SEO è gate hard (`error` ≥ 0.85); performance/accessibility/best-practices partono come **warning** (da promuovere a `error` in `lighthouserc.json` dopo la prima baseline verde).
- [x] **GitHub Projects sync** — `github-sync.yml` (**orario** `29 * * * *`) + `scripts/sync_github.rb`: i repo pubblici di Allan-Nava e hiway-media diventano post progetto su /projects; config e blocklist in `_data/github_sync.yml` (101 progetti). Oltre a creare i nuovi repo, **aggiorna i post sui push** del repo (campo `updated:` = ultimo push, + descrizione/stelle/linguaggio); tocca solo i post generati (marker `github:`), mai quelli scritti a mano.
