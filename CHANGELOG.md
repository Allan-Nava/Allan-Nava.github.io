# Changelog

Tutte le modifiche rilevanti a [allan-nava.github.io](https://allan-nava.github.io).
Formato ispirato a [Keep a Changelog](https://keepachangelog.com/it/1.1.0/); il sito segue
[Semantic Versioning](https://semver.org/lang/it/) applicato al **template** (layout, stili, build),
non ai contenuti: i post pubblicati non fanno versione.

Regola pratica: **major** = il tema cambia forma (restyling, riscrittura dei layout), **minor** =
nuove pagine, workflow o feature di build, **patch** = fix e ritocchi. Le milestone `vX.Y` della
[roadmap](docs/ROADMAP.md) sono una numerazione a parte, del backlog — non coincidono con questi tag.

## [Non rilasciato]

- Milestone [v2.4 — Motion & visual polish](https://github.com/Allan-Nava/Allan-Nava.github.io/milestone/2): movimento e ricchezza visiva sopra le fondamenta della v2.0.0.

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

[Non rilasciato]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.6.1...v2.0.0
[1.6.1]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.2.0...v1.4.0
[1.2.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Allan-Nava/Allan-Nava.github.io/releases/tag/v1.0.0
