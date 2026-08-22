---
title: "nolja.it — Associazione Culturale Corea–Italia"
layout: post
date: 2026-08-23 00:30
tag:
- site
- web
- wordpress
- php
- css
- nolja
image: ""
headerImage: false
projects: true
hidden: true # don't count this post in blog pagination
description: "Sito dell'Associazione Culturale Corea-Italia: tema WordPress block costruito da zero, trilingue IT/EN/KO, con font self-hosted, wizard di setup e una pipeline di qualita completa."
category: project
author: allan
---

Sito dell'**Associazione Culturale Corea–Italia**, con sede a Milano: eventi, scambi
linguistici e incontri fra la comunità coreana e quella italiana. Il progetto è un **tema
WordPress block (Full Site Editing) scritto da zero**, non un template comprato e ritoccato —
niente page builder, tutto sull'editor a blocchi nativo, così chi gestisce i contenuti resta
dentro WordPress e non dipende da me per cambiare un titolo.

<div>
    <img class="image" src="/assets/images/nolja-sezioni.jpg" alt="Sezioni della homepage nolja: mission, vision e servizi con alternanza chiaro/scuro" />
    <figcaption class="caption">Homepage: sezioni alternate e pillow effect nelle transizioni</figcaption>
</div>

## Design system

La palette esce dal logo — blu notte, giallo luna, azzurro polvere — ed è dichiarata una volta in
`theme.json`, insieme a scala tipografica e spazi: i pattern non contengono colori hard-coded.
Da lì nascono le sezioni alternate chiaro/scuro con il **pillow effect** (angoli arrotondati nelle
transizioni), l'hero full-viewport con il logo medaglione e un alone pulsante, e il bubble 놀자 in
stile fumetto fatto in CSS.

I font sono **self-hosted**, zero chiamate a Google Fonts: Inter per il testo latino e Noto Sans
KR per il coreano, quest'ultimo servito in 124 file woff2 con `unicode-range` sugli Hangul — il
browser scarica solo i blocchi di caratteri che la pagina usa davvero. È una scelta di GDPR
prima che di performance, ma paga su entrambi.

Le micro-interazioni di lettura (barra di avanzamento, tempo di lettura, indice automatico sulle
pagine legali, torna-su) sono scritte a mano, senza librerie di terze parti, e rispettano
`prefers-reduced-motion`. Il sito è pensato **trilingue IT / EN / KO**.

## Come è organizzato

La homepage è composta da **13 sezioni**, ognuna un block pattern indipendente: mission, vision,
servizi, progetti, come&play, newsletter, contatti, gallery, eventi, testimonianza, community,
blog. Chi edita ne sposta o rimuove una senza toccare il codice. Sotto ci sono **14 template**
(front page, blog, articolo, archivi, ricerca, pagine, pagine legali, 404) e un **custom post
type Evento** con data, luogo, locandina e archivio pubblico.

Il pezzo che mi piace più di tutti è il **setup wizard in 8 step**: attivato il tema, crea le
pagine dai pattern, imposta la homepage statica, logo e menu, e installa i plugin consigliati.
È idempotente — lo si può rilanciare senza creare doppioni. Serve a far sì che il tema, appena
installato, non sia una scatola vuota da riempire a mano seguendo un documento.

## La parte che non si vede

Il grosso del lavoro dell'ultimo giro non è stato CSS, ma rendere il progetto **verificabile**:

- **oltre 270 test** con la sola standard library — nessuna dipendenza — su struttura del tema,
  pacchetto zip, coerenza delle versioni e documentazione;
- **CI** su ogni push: `php -l` su tutto il tema, validazione di `theme.json`, versione allineata
  fra `style.css` e README, build dello zip come artifact;
- un **harness di render**: uno script rende i singoli pattern in HTML statico e ne cattura lo
  screenshot a 390 / 768 / 1280 px con Chrome headless, segnalando gli elementi che sforano il
  viewport. Verificare guardando, invece di fidarsi;
- **contrasti WCAG** calcolati sulle coppie di colori dichiarate nel markup, come gate dei test;
- **Lighthouse settimanale** confrontato con una baseline versionata: la CI diventa rossa solo su
  regressione, non su un punteggio assoluto;
- **health check** del sito ogni 30 minuti (HTTP, scadenza del certificato, versione del tema
  servita, `noindex` rimasto acceso per sbaglio);
- una **checklist pre-lancio eseguibile**: 23 controlli sul sito vivo — pagine chiave, redirect
  HTTPS, meta description, alt text, link interni rotti, robots e sitemap, banner cookie,
  selettore lingua, moduli. Solo richieste in lettura.

Backlog e roadmap stanno nel repo in Markdown come sorgente unica e vengono sincronizzati sulle
issue GitHub in automatico; release e pacchetto di deploy sono uno script solo, e il deploy gira
**in dry-run per default**.

## Due cose imparate

**Un modulo che sembra funzionare e non invia è peggio di nessun modulo.** Alcune pagine avevano
un `<form>` segnaposto che al submit mostrava un avviso: al visitatore sembrava un'iscrizione
riuscita. Ora al suo posto c'è un avviso esplicito, e un test impedisce a quel markup di
rientrare.

**I controlli automatici vanno smentiti prima di crederci.** Il check sul redirect http → https
dava un falso allarme perché la libreria HTTP seguiva i redirect da sé e vedeva solo la risposta
finale. Un `curl -I` a mano ha chiarito la cosa: corretto il controllo, e aggiunto un test che
blocca il ritorno del bug. Vale anche al contrario — la prima esecuzione della checklist ha
trovato due link rotti in home che nessuno aveva notato.

<div class="side-by-side">
    <div class="toleft">
        <figcaption class="caption">nolja — Associazione Culturale Corea–Italia</figcaption>
    </div>

    <div class="toright">
        <p></p>
        <p><a href="https://nolja.it" target="_blank" rel="noopener">https://nolja.it</a></p>
    </div>
</div>
