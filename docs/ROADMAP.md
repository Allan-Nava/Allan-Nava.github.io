# Roadmap — Milestone "Site 2.0"

Feature e miglioramenti implementabili sul sito, in ordine di rapporto valore/sforzo. Le checkbox tengono traccia dello stato; ogni voce è pensata per diventare una issue GitHub.

## 🟢 Quick win (mezza giornata o meno)

- [ ] **Paginazione di `/blog`** — oggi la pagina carica tutti i ~130 post insieme. Riabilitare `paginate: 10` + `paginate_path: "blog/:num/"` in `_config.yml` (il template `blog/index.html` supporta già il paginatore). Attenzione: `jekyll-paginate` conta anche i post `hidden`, quindi verificare il risultato con la CI prima del merge.
- [ ] **Lazy loading immagini** — aggiungere `loading="lazy"` alle immagini nei post e nei template (`_includes/`, `_layouts/`). Beneficio immediato sui post pieni di foto.
- [ ] **Badge di stato nel README** — badge del workflow Deploy e Uptime (`https://github.com/Allan-Nava/Allan-Nava.github.io/actions/workflows/jekyll.yml/badge.svg`).
- [ ] **Thumbnail nei post auto-generati da YouTube** — il feed/oEmbed espone `thumbnail_url`: usarla come `image:` nel front matter dei post creati da `scripts/sync_youtube.rb`, così i listing e i meta og:image hanno un'anteprima.
- [ ] **Disinstallare Renovate** (app GitHub) e chiudere le sue PR duplicate — resta solo Dependabot.

## 🟡 Medi (1–2 giorni)

- [ ] **Analytics GA4 o privacy-friendly** — creare la property GA4 e mettere il `G-XXXX` in `_config.yml` (l'include gtag è già pronto), oppure passare a GoatCounter/Plausible (script più leggero, niente cookie banner).
- [ ] **Modernizzazione stack Ruby** — in sequenza: merge PR Dependabot `github-pages` 211→223→232 (Jekyll 3.10), poi bump `ruby-version` a 3.3 nei workflow e rimozione del pin vecchio di `setup-ruby`, infine merge `html-proofer` 5.x adattando `Rakefile` (API `HTMLProofer` nuova) e i flag CLI in `checks.yml`.
- [ ] **Commenti con giscus** — commenti basati su GitHub Discussions (gratis, niente Disqus/ads): nuovo include `_includes/giscus.html` caricato in `post.html` dietro un toggle in `_config.yml`.
- [ ] **Ricerca client-side** — indice JSON generato da Liquid (`search.json`) + una pagina `/search` con fuzzy match in vanilla JS (o lunr.js): con 130+ post inizia a servire.
- [ ] **Pagina archivio per anno** — `/archive` con i post raggruppati per anno, generata in Liquid puro (nessun plugin richiesto).

## 🔴 Grandi (multi-giorno / decisioni)

- [ ] **Migrazione video LFS → YouTube** — caricare su YouTube i ~35 video oggi serviti via `github.com/raw` (quota banda LFS: 1 GB/mese) e sostituire gli embed nei ~20 post interessati; poi rimuovere `assets/video/` dal repo (−700 MB). Opzionale: riscrivere la history con BFG per recuperare anche il `.git` (~1 GB) — richiede force-push, da fare per ultima e con cautela.
- [ ] **Dark mode** — il tema Indigo è solo chiaro: aggiungere palette scura via `prefers-color-scheme` (+ eventuale toggle manuale) in `_sass/base/variables.sass` e derivati.
- [ ] **Ottimizzazione immagini automatica** — conversione WebP/AVIF con fallback e resize responsivo (`srcset`); valutare un job CI che comprime le immagini nuove sopra soglia (oggi la soglia è solo controllata a mano, il validator non guarda i pesi).
- [ ] **Lighthouse CI** — job in `checks.yml` che misura performance/SEO/accessibilità sulle pagine chiave e fallisce sotto un budget: previene regressioni man mano che si aggiungono feature.

## ✅ Fatte fuori milestone

- [x] **Mappa delle escursioni** — `/map` con Leaflet; i post con `lat`/`lng` nel front matter diventano marker (15 post geolocalizzati al lancio).
- [x] **Fitness tracker** — `/fitness` con tabelle e grafici SVG dei PR, dati in `_data/workouts.yml`.
- [x] **Strava sync** — `strava-sync.yml` + `scripts/sync_strava.rb`: post automatici dalle attività (richiede i secret `STRAVA_*`, setup in `deployment.md`).
- [x] **Pagina gear** — `/gear` con l'attrezzatura (voci placeholder da compilare nel sorgente).

## Come usare questa roadmap

Ogni voce è autoconsistente: si può aprire come issue GitHub (titolo = grassetto della voce, corpo = resto della descrizione) dentro una milestone "Site 2.0". Con `gh` autenticato:

```bash
gh api repos/Allan-Nava/Allan-Nava.github.io/milestones -f title="Site 2.0" -f description="Feature roadmap del sito"
gh issue create --milestone "Site 2.0" --title "..." --body "..."
```
