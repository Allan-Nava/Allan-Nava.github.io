# Changelog

Tutte le modifiche rilevanti a [allan-nava.github.io](https://allan-nava.github.io).
Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/); il sito segue
[Semantic Versioning](https://semver.org/lang/it/) applicato al **template** (layout, stili, build),
non ai contenuti: i post pubblicati non fanno versione.

Regola pratica: **major** = il tema cambia forma (restyling, riscrittura dei layout), **minor** =
nuove pagine, workflow o feature di build, **patch** = fix e ritocchi. Le milestone `vX.Y` della
[roadmap](docs/ROADMAP.md) sono una numerazione a parte, del backlog — non coincidono con questi tag.

## [Non rilasciato]

### Corretto

- **/tags: gerarchia e 190 KB in meno** (#147) — la pagina piu' pesante del sito (445 KB, l'unica sotto 99 di performance) spediva 1019 coppie (tag, post) anche se i `<details>` erano chiusi: chiusi o aperti, il browser scarica lo stesso. Ora gli archivi esistono solo per i tag con piu' di un post, con anteprima a 5 e rimando alla ricerca; i 190 tag con un post solo hanno il chip che porta dritto al post. **254 KB**, performance **91 → 95**. Corretto anche il `datetime` malformato delle voci.
- **Tag duplicati** (#148) — `iOS` e `ios`, `open source` e `open-source`, `github actions` e `github-actions`, `Murat4All` e `murat4all` erano archivi separati sullo stesso argomento. Unificati da `scripts/consolidate_tags.rb` (7 post); `validate_posts.rb` avvisa se due tag tornano a condividere lo slug.
- **La ricerca ignorava i 162 progetti** (#161) — `search.json` filtrava `hidden: true`, flag che
  serve a tenere i progetti fuori dalla paginazione del blog: la ricerca fingeva che quelle pagine
  non esistessero, proprio lo strumento che si usa quando non si sa dove cercare. Ora l'indice ha
  356 record (70 KB) e ogni risultato dichiara se è un post o un progetto.
- **Descrizioni che ripetevano il titolo** (#162) — 118 post generati avevano
  `description: "Video dal canale YouTube di Allan Nava: <titolo>"`, che finiva nel
  `<meta description>`, nel summary del feed, nell'estratto di ogni card e nell'anteprima dei
  risultati. Generatori corretti e storico ripulito con uno script one-shot.
- **Un 301 a ogni click** (#159) — i permalink dichiarano la barra finale, i 19 link interni no.
- **Logo dei progetti: variante neutra invece di quella per sfondo chiaro** — i README sono scritti
  per GitHub, che di default è chiaro, quindi il logo in pagina è quasi sempre `*-logo-light.svg`,
  cioè quello con l'inchiostro scuro (`#1f2328` su edgemix): sulle card del tema scuro era quasi
  invisibile, e la variante `-dark` lo sarebbe stata su quello chiaro. Ora `sync_github.rb` prova la
  variante `-mark` (solo colore d'accento, leggibile su entrambi i temi) con una richiesta HEAD, e
  ripiega su quella del README se non esiste. `edgemix` aggiornato.

### Modificato

- **SEO: il sito ora dice chi è.** Sei difetti che si sommavano, tutti nella `<head>`:
  la home usciva su Google come **"Home | Allan Nava"** (il `<title>` lo compone ora
  `_layouts/default.html`, con `{% seo title=false %}`); `description:` in `_config.yml`
  era una stringa vuota, quindi ogni pagina si presentava con la sola bio del tema;
  c'erano **due** `<meta name=description>` e **due** `<link rel=canonical>` per pagina
  (tema + plugin), e con due Google ne sceglie una; `twitter:site` era `@` perché
  `jekyll-seo-tag` legge solo `site.twitter.username`; `og:title` della home era "Home",
  cioè il titolo di ogni condivisione del sito.
- **Identità dichiarata**: nuovo `_includes/schema-person.html` — JSON-LD `Person` +
  `WebSite` con le `sameAs` verso GitHub, LinkedIn, YouTube, X, Instagram e dev.to
  (da `social.links` in `_config.yml`), su `/` e `/about/`; gli stessi profili sono
  linkati con `rel="me"` da `_includes/social-links.html`. È il segnale che collega il
  dominio alla persona per la query col nome proprio — mancava del tutto.
- **Descrizioni per pagina** su `/blog`, `/projects`, `/about`, `/tags`, `/map`, `/gear`
  e `/fitness` (prima ereditavano tutte la stessa).
- `checkfleet.yml`: l'assertion sulla home era ancora `<title>Home | Allan Nava</title>`
  e il monitor ha dato il sito **giu' per ore** mentre rispondeva 200 su tutto (12 OK,
  1 BAD). Ora asserisce il prefisso stabile `<title>Allan Nava — `: la tagline e' copy
  e non deve poter dichiarare un'outage. Aggiunta anche la riga `Sitemap:` di robots.txt
  fra i controlli (il file e' un template Liquid: se perdesse il front matter uscirebbe
  grezzo e nessun altro controllo se ne accorgerebbe).
- `_config.yml`: aggiunte `tagline`, `social`, `description` e `google_site_verification`
  — il token della proprieta' Search Console `https://allan-nava.github.io/`, che
  `jekyll-seo-tag` stampa come `<meta name="google-site-verification">` su tutte le
  pagine. Non va rimosso dopo la verifica: Google ricontrolla il tag e senza torna
  proprieta' non verificata.

## [2.5.0] — 2026-08-17

Il giro più lungo dalla 2.0.0: secondo tema, PWA, galleria foto, feed riscritti e lo stack
Ruby portato alla 3.3. Resta una **minor** e non una major perché il tema non cambia forma —
guadagna una seconda palette, non un'altra impaginazione.

### Aggiunto

- **Tema chiaro con toggle** — il sito ha due palette (`palette-dark` / `palette-light` in
  `_sass/base/tokens.scss`) e un interruttore nella nav; `_includes/theme-init.html` applica la
  scelta salvata **prima del primo paint**, così non si vede il lampo del tema sbagliato.
  `scripts/check_contrast.rb` verifica 52 coppie di colori su entrambi i temi, soglia 6:1.
- **PWA** — manifest, icone generate da `scripts/generate_pwa_icons.rb`, pagina `/offline` e
  service worker: HTML sempre network-first, in cache solo font, icone e immagini.
- **Galleria foto con lightbox** — due o più immagini consecutive diventano una griglia
  (`_plugins/photo_gallery.rb`), apribile a tutto schermo.
- **Card social per-post** — `scripts/generate_og_cards.rb` genera le anteprime in
  `assets/images/og/`; `_plugins/og_image.rb` le assegna a `page.og_card`.
- **Immagini responsive** — `scripts/optimize_images.rb` produce le varianti WebP/AVIF e
  `_plugins/responsive_images.rb` avvolge gli `<img>` locali in `<picture>`.
- **Commenti giscus attivi**, con il riquadro che segue il tema del sito via `postMessage`.
- **Sottotitolo di pagina** (`subtitle:` nel front matter) e `<h1>` uniforme per tutte le pagine:
  prima cinque pagine arrivavano allo screen reader senza titolo di primo livello.
- **Card social di default** — `assets/images/og-default.png` (1200x630), generata da
  `scripts/og_card.html` con `ruby scripts/generate_og_card.rb`. `default.html` la usa come
  `og:image` per ogni pagina senza `image:`: 212 post su 330 finora venivano condivisi senza
  anteprima. I post video mantengono la loro thumbnail.
- **Descrizione del video nel corpo dei post generati** — `description_html` in `sync_youtube.rb`.
- **GitHub repo images** — `sync_github.rb` estrae il logo dal README del repo e lo mette in `image:`; il placeholder generativo resta il fallback per i repo che un logo non ce l’hanno.
- **YouTube location extraction migliorata** — oltre a `recordingDetails.location` dalla YouTube API, se disponibile, ora fallback al geocoding della descrizione: estrae città con pattern (`📍 Roma`, `filmed in London`, etc) e converte in lat/lng con Nominatim (OpenStreetMap, gratuito, nessuna API key).

### Modificato

- **Feed RSS fatti in casa** — via `jekyll-feed`, che non sa escludere i post `hidden`: i progetti
  generati dal sync occupavano metà di `/feed.xml`. Ora `feed.xml` (blog) e `/projects/feed.xml`
  sono template a mano.
- **Listing a griglia responsive** — due colonne da 860px, tre da 1240px, con `minmax(0, 1fr)`
  perché uno slug lungo non sfondi la colonna.
- **Stack Ruby modernizzato** — `github-pages` 232 (Jekyll 3.10), Ruby **3.3** nei workflow,
  `html-proofer` 5.x con i flag CLI rinominati in `Rakefile`, `checks.yml` e `link-check.yml`.
- **Interfaccia tutta in inglese** (filtri dei progetti compresi) e **404 asciugata**: niente più
  bottoni e listing su una pagina d'errore.
- **Smoke test più tollerante** con la propagazione della CDN dopo il deploy.

### Corretto

- **`jemoji` rompeva `/map`** — gira dopo Liquid sull'HTML finito e ignora solo `pre`/`code`/`tt`:
  uno shortcode dentro una stringa JS diventava un `<img>` e la pagina moriva. Titoli passati con
  `replace: ":"` e popup costruiti col DOM invece che concatenando HTML.
- **`data-count` era usato da due cose diverse** — il conteggio animato della home svuotava la
  galleria dei post, che usava lo stesso attributo per il numero di foto (ora `data-photos`).
- **Titoli duplicati nei post** — il primo heading del corpo ripeteva il `title:` del front matter
  in 259 post; `scripts/dedupe_title_heading.rb` li ha ripuliti e il validator ora avvisa.
- **Permalink canonici per Projects e Tags** — `projects.html` e `tags.html` ora hanno `permalink: /projects/` e `/tags/`, così gli URL pubblicati, la nav e i check live coincidono con le canoniche URL del sito. Questo elimina il 404 sulla tag cloud, i redirect inutili e il mismatch fra live URL e canonical. I check di smoke e Lighthouse sono aggiornati ai percorsi finali.
- **Toolchain locale ripristinato** — `.ruby-version` con **3.3.12** (la stessa minor della CI): dopo il passaggio a `html-proofer ~> 5.0`, che richiede Ruby ≥ 3.1, in locale il bundle non si installava più e `bundle exec jekyll build` moriva con `Bundler::GemNotFound`. Build, `rake test_internal` e Lighthouse tornano eseguibili prima del push.
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

[Non rilasciato]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.5.0...HEAD
[2.5.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.4.0...v2.5.0
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
