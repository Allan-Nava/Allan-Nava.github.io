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

- **YouTube location extraction** — `sync_youtube.rb` usa YouTube Data API per estrarre `recordingDetails.location` (lat/lng) da ogni video. Se disponibili, le aggiunge automaticamente al post front matter — la mappa `/map` si aggiorna senza intervento manuale. Fallback a RSS feed se `YOUTUBE_API_KEY` non è configurato.
- **Trigger workflow su tag e release** — `jekyll.yml` ora ascolta a `push.tags` (pattern `v*`) e `release.types: published`, oltre al push su master. Ogni tag o GitHub Release pubblica genera automaticamente un deploy.
- **Skill graphify** — `.claude/skills/graphify.md` per invocare `graphify` dall'IDE e analizzare la struttura del repository.
- **Il titolo della home entra parola per parola** — ogni parola sale in dissolvenza con 42 ms di ritardo sulla precedente; sottotitolo, CTA e numeri arrivano dopo la frase. Le parole le avvolge il JS (classe `is-split`): senza JavaScript, o con `prefers-reduced-motion`, resta la dissolvenza a blocco di prima, quindi il titolo non è mai invisibile. Il rotator viene **avvolto** e non marcato — ha già una sua `animation`, e marcarlo l'avrebbe sostituita (stessa trappola della 2.3.0).

### Modificato

- `.github/workflows/youtube-sync.yml` — aggiunto `YOUTUBE_API_KEY` dal secret, commentato per indicare che abilita la location extraction.
- `.gitignore` — aggiunto `graphify-out/` per escludere gli artefatti di analisi.

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

[Non rilasciato]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.3.0...HEAD
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
