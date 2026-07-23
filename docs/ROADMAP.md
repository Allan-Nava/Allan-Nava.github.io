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

## v3.0 — Big rocks

- [ ] **Migrazione video LFS → YouTube** — caricare su YouTube i ~39 `.MOV` (`assets/video/`, serviti via `github.com/raw` con quota banda LFS 1 GB/mese), sostituire gli embed, rimuovere `assets/video/` (−700 MB). Opzionale: BFG sulla history (force-push, per ultima).
- [ ] **Light mode / toggle tema** — il tema è già **scuro** (`$background: #050505` in `_sass/base/variables.sass`); manca una palette chiara e un toggle `prefers-color-scheme`. NB: essendo scuro, ogni nuovo stile va verificato per contrasto (es. `strong`/`code` avevano colori pensati per sfondo chiaro → testo invisibile, corretto).
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
- [x] **GitHub Projects sync** — `github-sync.yml` (giornaliero) + `scripts/sync_github.rb`: i repo pubblici di Allan-Nava e hiway-media diventano post progetto su /projects; config e blocklist in `_data/github_sync.yml` (101 progetti al primo run).
