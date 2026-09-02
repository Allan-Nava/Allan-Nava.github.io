# intent.md — allan-nava.github.io

Perché questo sito esiste e in base a cosa si decide cosa entra e cosa no.

Gli altri documenti dicono **come**: `CLAUDE.md`/`AGENTS.md` le regole operative e le trappole,
`docs/` le guide human-facing, `docs/ROADMAP.md` il backlog versionato, `CHANGELOG.md` lo storico.
Questo dice **perché**, ed è il documento contro cui misurare una proposta prima di scriverla.

## 1. Cos'è

Il sito personale di Allan Nava — DevOps engineer a Milano, infrastrutture video live — su
`https://allan-nava.github.io`: Jekyll sul tema [Indigo](https://github.com/sergiokopplin/indigo),
GitHub Pages, deploy da `master` via GitHub Actions. Un solo `_posts/` contiene tutto (**373 file**:
209 blog, 164 progetti), e il front matter `category` separa i due tipi.

Non è un sito vetrina con qualche post: è **l'archivio principale** di dieci anni di scrittura, video,
repository ed escursioni — 151 post con un video YouTube, 114 schede di repo generate, 166 post con
coordinate sulla mappa.

## 2. A chi serve

Nell'ordine in cui contano:

1. **Chi cerca "Allan Nava"** — recruiter, clienti, colleghi. Devono trovare il sito, capire in dieci
   secondi cosa fa e arrivare a un progetto vero. Da qui il lavoro su identità e SEO: JSON-LD `Person`
   con le `sameAs`, `rel="me"`, Search Console, tagline e `description` scritte per lo snippet di Google.
2. **Chi arriva da una ricerca tecnica** su un problema specifico e finisce su un post. Deve leggerlo
   senza attriti — pagina veloce, tema che rispetta il suo, codice leggibile, niente popup.
3. **Allan fra cinque anni**, che cerca come aveva risolto una cosa. Da qui `/search`, `/archive`,
   `/tags`, `/map` e l'ossessione per non perdere contenuto vecchio.

Nessuna di queste tre persone ha chiesto una newsletter, un banner cookie o un carosello.

## 3. Obiettivi

- **Essere il nodo canonico dell'identità online.** Il sito è il centro; GitHub, YouTube, LinkedIn,
  Instagram, dev.to sono raggi. I profili vengono da `social.links` in `_config.yml`, mai hard-codati.
- **Assorbire da solo i contenuti che nascono altrove.** I video li pubblica YouTube, i repo GitHub, le
  attività Strava: i sync (`youtube-sync`, `github-sync`, `strava-sync`, `robots-sync`) li riportano qui
  come post. Scrivere a mano deve restare una scelta, non un obbligo per essere aggiornati.
- **Sopravvivere all'abbandono.** Nessun servizio a pagamento, nessun database, nessun runtime da
  aggiornare: se nessuno tocca il repo per un anno, il sito continua a funzionare identico.
- **Restare misurabilmente buono.** Lighthouse, contrasto WCAG, link interni e uptime sono gate in CI,
  non impressioni.

## 4. Non-obiettivi

Cose che il progetto ha deliberatamente **scelto di non fare** — riproporle richiede una ragione nuova,
non un "sarebbe bello":

- **Non è un CMS.** Nessun backend, nessun editor online da presidiare (jekyll-admin è solo comodità
  locale). La fonte di verità è un file Markdown in git.
- **Non ospita media pesanti.** I `.MOV` in Git LFS sono un debito da estinguere (#136), non un modello:
  i video nuovi sono embed YouTube con la facade `<lite-youtube>`.
- **Non insegue il traffico.** Niente newsletter forzate, niente contenuto scritto per la keyword,
  niente interstitial. L'analytics è GA4 configurato per **non** partire su localhost e per rispettare
  DNT/GPC; si spegne commentando una riga.
- **Nessuna dipendenza a runtime.** Zero CDN, zero framework JS: font self-hosted (47 KB), facade video
  scritta a mano, ricerca client-side su un indice generato a build time. Ciò che il browser scarica
  arriva da `allan-nava.github.io`.
- **Non è un progetto di design fine a sé stesso.** Ogni giro di restyling (v2.3 → v2.6) è partito da
  difetti visti sul sito **pubblicato**, non da un elenco di buoni propositi.

## 5. Principi

- **Build time invece di runtime.** Se una cosa si può calcolare durante la build — thumbnail, OG card,
  indice di ricerca, TOC, conteggi, placeholder delle card, `<picture>` responsive — si calcola lì. Il
  browser riceve HTML finito.
- **Progressive enhancement, sempre.** Ogni funzione JS o CSS moderna sta dietro un controllo, e la
  pagina senza di essa resta **completa**, mai rotta e mai vuota: il toggle del tema è `hidden` finché
  il JS non parte (il tema segue comunque `prefers-color-scheme`), i chip dei filtri non compaiono e la
  lista resta intera, i numeri animati sono già corretti nell'HTML, il bottone "copia codice" esiste solo
  se esiste la Clipboard API.
- **Il contenuto sopravvive al template.** I post sono Markdown con front matter semplice; tema,
  plugin e Sass si possono buttare via senza toccare `_posts/`.
- **L'automazione non distrugge il lavoro a mano.** Ogni script tocca solo ciò che ha generato lui
  (marker `github:`), gira idempotente e ha un `DRY_RUN=1`. Gli hook dei plugin girano due volte sullo
  stesso post: ogni trasformazione deve reggerlo.
- **Verificare sul ramo che gira davvero.** Le regressioni peggiori del repo — `command -v` in forma ad
  array, `magick` che su Ubuntu è `convert`, i post datati nel futuro in UTC — sono passate tutte in
  locale e fallite in CI. Il controllo va fatto dove il codice esegue.
- **Un difetto sistemato una volta diventa un controllo.** `validate_posts.rb`, `check_contrast.rb`,
  i budget Lighthouse e i target `checkfleet.yml` esistono perché qualcosa si era rotto in silenzio.
- **Accessibilità e contrasto non sono negoziabili.** Due temi completi, ogni token in entrambe le
  palette, 52 coppie ≥ 6:1, accessibility 100 come gate hard.

## 6. Vincoli che ne discendono

Non sono preferenze: cambiarli cambia il progetto.

- **GitHub Pages** come hosting → niente server, niente redirect lato server, niente segreti a runtime.
- **`github-pages` 232** (Jekyll 3.10, kramdown 2.4) → si sta sulla versione che Pages garantisce, non
  sull'ultima Jekyll.
- **Pages su `build_type: workflow`** → i `_plugins/` custom girano davvero sul sito pubblicato. È la
  condizione che rende possibile metà delle feature: se torna `legacy`, saltano.
- **Ruby 3.3** in locale e in CI, allineati (`html-proofer ~> 5` richiede ≥ 3.1).
- **`master`**, nessun `main`. Il push lo fa Allan, mai un agent.

## 7. Come si decide se una cosa entra

Una proposta entra se risponde sì a tutte:

1. Serve a una delle tre persone del §2, e si capisce **quale**.
2. Funziona senza JavaScript, o degrada in modo che la pagina resti completa.
3. Non aggiunge una dipendenza a runtime né un servizio esterno da presidiare.
4. Non peggiora i gate: `validate_posts.rb`, html-proofer interno, budget Lighthouse, contrasto.
5. È verificabile — si può guardare il risultato, contarlo o asserirlo, non solo dichiararlo fatto.
6. Lascia `_posts/` portabile.

Quello che non passa il filtro finisce in `docs/ROADMAP.md` con scritto **perché** è fermo — di solito
"servono credenziali" o "serve un account esterno", non "non si sa come farlo".

## 8. Dove sta andando

Le uniche voci di codice ancora aperte (milestone `v3.0` e code di v2.x):

- **Migrazione video LFS → YouTube** (#136) — i ~39 `.MOV` in `assets/video/` sono l'ultima cosa nel
  repo che contraddice il §4: pointer LFS rotti sul sito live, ~700 MB, quota banda mensile.
- **Consolidamento dei tag duplicati** (#148) — cinque gruppi di varianti che frammentano gli archivi.
- **Riempire `/gear`** (climbing, snowboard, dev setup) — non deducibile dal repo, e inventarlo sarebbe
  peggio del vuoto: per questo la pagina è ancora fuori dalla nav.
- **In attesa di credenziali o account**: secret Strava (#130), newsletter RSS-to-email (#132),
  webmentions (#133).

Il resto è manutenzione: i sync girano, i gate tengono, e il sito si aggiorna anche quando nessuno
scrive.
