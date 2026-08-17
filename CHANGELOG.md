# Changelog

Tutte le modifiche rilevanti a [allan-nava.github.io](https://allan-nava.github.io).
Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/); il sito segue
[Semantic Versioning](https://semver.org/lang/it/) applicato al **template** (layout, stili, build),
non ai contenuti: i post pubblicati non fanno versione.

Regola pratica: **major** = il tema cambia forma (restyling, riscrittura dei layout), **minor** =
nuove pagine, workflow o feature di build, **patch** = fix e ritocchi. Le milestone `vX.Y` della
[roadmap](docs/ROADMAP.md) sono una numerazione a parte, del backlog — non coincidono con questi tag.

## [Non rilasciato]

### Aggiunto

- **Card social di default** — `assets/images/og-default.png` (1200x630), generata da
  `scripts/og_card.html` con `ruby scripts/generate_og_card.rb`. `default.html` la usa come
  `og:image` per ogni pagina senza `image:`: 212 post su 330 finora venivano condivisi senza
  anteprima. I post video mantengono la loro thumbnail.
- **Descrizione del video nel corpo dei post generati** — `description_html` in `sync_youtube.rb`.
- **GitHub repo images** — `sync_github.rb` estrae il logo dal README del repo e lo mette in `image:`; il placeholder generativo resta il fallback per i repo che un logo non ce l’hanno.
- **YouTube location extraction migliorata** — oltre a `recordingDetails.location` dalla YouTube API, se disponibile, ora fallback al geocoding della descrizione: estrae città con pattern (`📍 Roma`, `filmed in London`, etc) e converte in lat/lng con Nominatim (OpenStreetMap, gratuito, nessuna API key).

### Corretto

- **Paginazione del blog fuori posto sul desktop** — con la griglia responsive dei listing `.list` è diventata un `display: grid`, e il blocco della paginazione (che stava dentro la section) si è ritrovato a occupare una cella: finiva nella prima colonna invece che centrato sotto alle card. Ora il markup lo tiene fuori dalla griglia, e `grid-column: 1 / -1` fa da rete di sicurezza.
- **L’estrazione del logo dal README non trovava quasi nulla** — cercava solo la sintassi
  Markdown `![alt](url)`, ma i README di questi progetti mettono il logo in HTML
  (`<img src="docs/assets/logo.svg">` dentro un blocco centrato): risultato `nil`. Dove invece il
  Markdown c’era, vinceva il **primo badge** del file (shields.io, il badge del workflow CI),
  cioè la copertina sbagliata. Ora legge sia Markdown sia `<img>`, scarta i badge, gestisce
  `?raw=true`/`#anchor` e i titoli `![x](url "t")`, preferisce un raster all’SVG (l’immagine
  finisce anche in `og:image`, e i social non renderizzano gli SVG) e risolve i path relativi con
  il **default branch** del repo invece di assumere `main`.
- **`sync_youtube.rb` era rotto su master**: chiamava `description_html` senza definirla, quindi il
  cron ogni 3 ore sarebbe morto con `NoMethodError` al primo video nuovo (e, con `failure-issue.yml`
  attivo, avrebbe aperto una issue a ogni giro). Helper ripristinato.
- **Il deploy non partiva più sui tag** — `jekyll.yml` ascoltava anche `push.tags` e
  `release: published`, ma l'ambiente `github-pages` ammette solo il branch di default: il run
  partito dal tag falliva *e*, per via del concurrency group `pages` con `cancel-in-progress`,
  cancellava il deploy buono di `master`. Con `v2.4.0` quel push non ha pubblicato niente.
  Ora il deploy si attiva solo su master, cron e dispatch; le release le fa `release.yml`, che
  non tocca Pages.
- **Titolo della release duplicato** — era il nome del tag, che la pagina delle release mostra
  già sotto al titolo. Ora è la prima riga del tag annotato.

## [2.4.0] — 2026-08-11

Contenuto navigabile (milestone v2.1) e automazioni di piattaforma (milestone v2.2).

### Aggiunto

- **Release GitHub automatica dai tag** — `.github/workflows/release.yml`: un tag `v*` crea la
  release prendendo le note **da questo file** (sezione della versione corrispondente); se manca,
  ripiega sul messaggio del tag annotato e infine sulle note generate da GitHub. Nessuna action di
  terze parti: `gh` con il token del runner.
- **Allerta sui workflow schedulati** — `.github/workflows/failure-issue.yml` (riusabile) agganciato
  a youtube-sync, github-sync, robots-sync, strava-sync e uptime: un cron che fallisce apre una issue
  `ci-failure`, e i fallimenti successivi commentano quella aperta invece di crearne una nuova.
- **Link checker mensile** — `.github/workflows/link-check.yml`: html-proofer sui link **esterni** il
  primo del mese; i morti finiscono in una issue `link-rot` e il workflow resta verde, perché un sito
  altrui che sparisce non deve bloccare il deploy. I link **interni** restano un gate su ogni PR.
- **YouTube location extraction** — `sync_youtube.rb` usa YouTube Data API per estrarre `recordingDetails.location` (lat/lng) da ogni video. Se disponibili, le aggiunge automaticamente al post front matter — la mappa `/map` si aggiorna senza intervento manuale. Fallback a RSS feed se `YOUTUBE_API_KEY` non è configurato.
- **Trigger workflow su tag e release** — `jekyll.yml` ora ascolta a `push.tags` (pattern `v*`) e `release.types: published`, oltre al push su master. Ogni tag o GitHub Release pubblica genera automaticamente un deploy.
- **Skill graphify** — `.claude/skills/graphify.md` per invocare `graphify` dall'IDE e analizzare la struttura del repository.
- **Pagine di navigazione del contenuto** (milestone v2.1): `/archive` (post per anno), `/stats` (totali, post per anno e tag più usati con barre in CSS), `/videos` (griglia delle thumbnail dei 120 post video), `/search` (indice `search.json` di 194 voci generato a build time + ricerca nel browser, con `?q=` supportato).
- **Controlli di lettura** — barra di avanzamento e bottone "torna su" (scroll-driven, nessun JS), bottone "copia" sui blocchi di codice (solo se esiste la Clipboard API).
- **Serie di post** — campo `series:` nel front matter → box "Part N of M" con l'elenco degli episodi.
- **404 utile** — tre vie d'uscita (home, ricerca, archivio) e gli ultimi post, invece del solo "page not found".
- **Commenti giscus** — `_includes/giscus.html` + blocco `giscus:` in `_config.yml`: inerte finché `repo-id` e `category-id` restano vuoti.
- **Il titolo della home entra parola per parola** — ogni parola sale in dissolvenza con 70 ms di ritardo sulla precedente; sottotitolo, CTA e numeri arrivano dopo la frase. Le parole le avvolge il JS (classe `is-split`): senza JavaScript, o con `prefers-reduced-motion`, resta la dissolvenza a blocco di prima, quindi il titolo non è mai invisibile. Il rotator viene **avvolto** e non marcato — ha già una sua `animation`, e marcarlo l'avrebbe sostituita (stessa trappola della 2.3.0).

### Modificato

- `.github/workflows/youtube-sync.yml` — aggiunto `YOUTUBE_API_KEY` dal secret, commentato per indicare che abilita la location extraction.
- `.gitignore` — aggiunto `graphify-out/` per escludere gli artefatti di analisi.
- **Related posts per affinità** — il box in fondo ai post ordina per numero di tag condivisi e lo dichiara ("3 shared tags"); prima mostrava i post più recenti che avessero un tag qualsiasi in comune.
- **Rotazione della parola nel titolo più lenta** — ciclo da 10,5 s a 15 s (5 s per parola) e cascata d'ingresso da 42 ms a 70 ms per parola.
- Le card dei listing non dipendono più dalla pagina (`.home`) ma dalla sezione (`.home-section`), così la 404 riusa gli stessi stili invece di mostrare immagini a piena pagina.

## [2.3.0] — 2026-08-10

Il titolo della home si muove, e con lui l'apertura.

### Aggiunto

- **Parola che ruota** nel titolo della home: *tools → pipelines → systems*, parole impilate nella
  stessa cella che si incrociano in dissolvenza. La finestra si stringe sulla parola visibile usando
  larghezze **misurate dal browser** (`--w0…--w2`), rimisurate dopo `document.fonts.ready` e al
  ridimensionamento — la taglia del titolo è fluida, e le stime in `ch` con un font a peso 800
  tagliavano le parole. I lettori di schermo leggono una versione fissa (`.sr-only`).
- **Ingresso a cascata** dell'apertura (kicker, titolo, sottotitolo, CTA, numeri) e sottolineatura
  delle parole in evidenza che si accende dopo il titolo.
- **Parallasse dell'apertura**: sale e sfuma uscendo dalla vista (scroll-driven).
- **Righe delle sezioni** che si disegnano da sinistra quando la sezione entra nella vista.
- Utility `.sr-only` in `_sass/base/helpers.sass`.

### Corretto

- La rotazione della larghezza non partiva: il rotator è anche un `.em`, e la regola più specifica
  della sottolineatura **sostituiva** l'animazione (`animation` è una proprietà sola). Ora le due
  animazioni sono dichiarate insieme.
- Prima versione con lista scorrevole dietro una finestra: i glifi della parola vicina sbordavano
  dalla line-box e affioravano sopra a quella visibile. Risolto passando alla dissolvenza incrociata.

## [2.2.0] — 2026-08-10

Navigazione e home rifatte: erano le due parti rimaste con la forma da template.

### Modificato

- **Navigazione**: da barra a tutta larghezza a **isola flottante in vetro**, centrata e staccata dal
  bordo. La striscia sticky resta a tutta larghezza ma è trasparente ai click (`pointer-events`), così
  il contenuto sotto resta cliccabile. La pillola della voce attiva ha un `view-transition-name`
  proprio: cambiando pagina **scivola** da una voce all'altra invece di sparire.
- **Home**: da "avatar + due bottoni" a pagina editoriale — dichiarazione grande con parole in
  evidenza, numeri, sezioni curate (ultimi progetti, ultimi post, argomenti) e chiusura con contatti.
  Il testo dell'apertura vive in `index.html`, unico punto da modificare.
- Lingua dell'interfaccia uniformata all'**inglese** (era mista: sottotitoli e filtri in italiano,
  resto in inglese).
- `--nav-height` a 68px per tenere conto dell'isola flottante: le ancore non finiscono più sotto la nav.

### Corretto

- Le sezioni della home si incollavano l'una all'altra: `margin-top: 0` delle liste vinceva per
  specificità sul margine di sezione.

## [2.1.0] — 2026-08-10

Movimento e ricchezza visiva sopra le fondamenta della 2.0.0. Milestone
[v2.4 — Motion & visual polish](https://github.com/Allan-Nava/Allan-Nava.github.io/milestone/2).
Ogni effetto è progressive enhancement: dietro `@supports`/`@media`, spento da `prefers-reduced-motion`.

### Aggiunto

- **Placeholder generativo** per le card senza `image:`: monogramma su gradiente scelto da un hash
  stabile del titolo (`_plugins/card_placeholder.rb`). Riguarda 112 card di progetto.
- **Filtri su `/projects`**: chip dei 12 tag più usati (`_plugins/project_tags.rb`), filtro
  client-side e contatore dei risultati. Senza JavaScript i chip non compaiono e la lista resta intera.
- **Reveal delle card allo scroll** e **nav che guadagna ombra**, con `animation-timeline: view()/scroll()`.
- **View Transitions** fra le pagine: la card cliccata si trasforma nell'header del post.
- **Hero animato**: alone luminoso dietro l'avatar ed entrata a cascata di titolo, bio, CTA e numeri.
- **Numeri della home** (post, progetti, video, tag) contati in Liquid e animati in ingresso.
- **Fade-in delle thumbnail** al caricamento e **spotlight** che segue il puntatore sulle card.
- Micro-interazioni: underline animata sui link dei post, stato `:active`, freccia `↗` che scatta.
- `CHANGELOG.md` (questo file).

### Modificato

- Titoli in "display": stesso font variabile, peso 800 e tracking più stretto.
- Il reveal allo scroll **non** si applica a `/tags`: animare le migliaia di righe di quella pagina
  costava ~5 punti di performance in Lighthouse (86 con l'animazione, 91 senza).

### Corretto

- L'attributo `hidden` non nascondeva nulla dove un componente dichiara `display: block`
  (`[hidden] { display: none !important }` in `general.sass`): è il motivo per cui il primo filtro
  mostrava progetti fuori tema.
- I commenti `//` negli script inline venivano mangiati da `_layouts/compress.html`, che collassa le
  newline: tutto il codice successivo finiva commentato. Ora si usa `/* … */`.
- Il numero sul chip di filtro non coincideva con i risultati: il conteggio è passato da
  "occorrenze del nome" a "post per slug".

## [2.0.0] — 2026-08-10

Restyling completo del tema Indigo, rimasto fino a qui quello originale (pensato per fondo chiaro)
con sopra una serie di pezze. Milestone [v2.3 — Design & UI](https://github.com/Allan-Nava/Allan-Nava.github.io/milestone/1).

### Aggiunto

- **Design token** in CSS custom properties (`_sass/base/tokens.scss`): colori, spazi, raggi, motion,
  tipografia e layout. Unica fonte di verità, e prerequisito del light mode.
- **Font variabile self-hosted** (Inter, subset latin, 47 KB) con `font-display: swap` e preload.
- **Nav sticky** full-width con brand, stato attivo sulla pagina corrente e skip-link; il contenuto
  vive dentro un `<main>`.
- **Card con thumbnail** su `/blog` e `/projects`, hero della home con CTA, footer a colonne.
- `_plugins/youtube_thumbnails.rb` — ricava la thumbnail dal `videoid` della facade per **114 post**
  che avevano `image: ""` (vale anche per `og:image`).
- `_plugins/toc.rb` — indice dei contenuti per i post con almeno 3 heading.
- `name:` in `_config.yml`: hero, brand e footer stampavano una stringa vuota perché il campo non esisteva.
- `rake test_internal` e flag dell'html-proofer allineati a quelli di `checks.yml`.

### Modificato

- **Tipografia fluida** con `clamp()` e corpo dei post limitato a `--measure` (68ch).
- **`code`/`pre` e syntax highlighting** portati su palette scura: prima erano la palette GitHub
  chiara, cioè slab bianchi in mezzo alla pagina nera.
- **Breakpoint mobile** da 400px a 560px: i telefoni attuali stanno fra 390 e 430 CSS px e finivano
  nel layout tablet.
- Gate Lighthouse: `accessibility` e `best-practices` da `warn` a **`error`** (0.95), SEO a 0.90.

### Corretto

- Testo invisibile sui bottoni verdi in hover (`a:hover` di `polish.sass` vinceva sul colore del bottone).
- Audit di accessibilità: `<main>` mancante, nome accessibile di brand e social link, salto `h1` → `h3`
  nelle card. Risultato: **accessibility 100** (performance 99–100, best-practices 100, SEO 100).

## [1.6.1] — 2025-03-25

Contenuti: due anni di post, video e foto (vlog, unboxing, viaggi), più correzioni di date e asset.

## [1.6.0] — 2023-03-07

Passaggio del deploy a **GitHub Actions** (`.github/workflows/jekyll.yml`) al posto del workflow
"Refresh AJ", pulizia di `_config.yml` e nuovi post tech (Go SDK, Haivision, OvenMediaEngine).

## [1.5.1] — 2023-01-23

Workflow `uptime.yml` per il monitoraggio del sito, post su Docker/FFmpeg NVENC e libreria Go FFmpeg.

## [1.5.0] — 2022-06-25

Deploy automatico "Refresh AJ" verso GitHub Pages.

## [1.4.0] — 2022-02-01

Prima automazione di build e deploy del sito.

## [1.2.0] — 2021-12-24

## [1.1.0] — 2020-08-28

## [1.0.0] — 2020-07-22

Prima versione pubblica del sito sul tema Indigo.

[Non rilasciato]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.4.0...HEAD
[2.4.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.6.1...v2.0.0
[1.6.1]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.2.0...v1.4.0
[1.2.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/releases/tag/v1.0.0
