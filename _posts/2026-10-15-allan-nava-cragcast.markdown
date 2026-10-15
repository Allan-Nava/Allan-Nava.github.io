---
title: "cragcast: si arrampica domani?"
layout: post
date: 2026-10-15 11:00
tag:
- climbing
- java
- spring boot
- react
- github-actions
- openstreetmap
image: ""
headerImage: false
description: "Come cragcast decide se una falesia lombarda è asciutta domani — meteo, pioggia dei giorni prima ed esposizione della parete — e come gira ogni ora senza un server, con GitHub Pages e servizi gratuiti."
category: blog
author: allan
lang: it
locale: it_IT
---

La domanda che mi faccio ogni venerdì sera è sempre la stessa: **domani la roccia è asciutta?**
Le app meteo dicono se pioverà, ma la cosa che rovina una giornata in falesia è la pioggia di
*ieri*: una placca esposta a sud dopo 8 mm di pioggia di solito il giorno dopo è a posto, una
parete a nord spesso no. [cragcast](https://allan-nava.github.io/cragcast/) mette questo
ragionamento nel codice, per 75 falesie della Lombardia.

## Il verdetto

Per ogni falesia e per oggi, domani e dopodomani, cragcast dà **si va**, **forse** o **no**, con
i motivi scritti accanto. Le regole sono poche e stanno tutte in una classe Java,
`ConditionsScorer`, come costanti con un nome:

- più di **2 mm di pioggia** fra le 8 e le 18 → no;
- **vento oltre 50 km/h** → no;
- pioggia delle **48 ore prima** oltre 10 mm su una parete al sole (S, SE, SO), oltre 5 mm su
  una in ombra → forse, perché la roccia può essere ancora bagnata;
- **massima sotto i 5 °C** → forse; **oltre i 32 °C** su una parete al sole → forse.

Sono una prima euristica, non un modello: la calibrazione contro giornate vere in falesia è il
prossimo passo, e i dati li raccolgo io quando ci vado.

Il punto debole è l'**esposizione della parete**. Le falesie vengono da OpenStreetMap, e il tag
che dice dove guarda la parete (`climbing:orientation`) oggi c'è solo su 2 delle 75. Quando
manca, cragcast giudica la parete come se fosse in ombra, la lettura prudente, e lo dice. La
pagina spiega come aggiungere il tag su OSM: è il modo più diretto per rendere il verdetto più
preciso.

## Come gira, senza un server

Il piano iniziale era un servizio Spring Boot con PostgreSQL su una VM ARM del free tier di
Oracle Cloud, con Terraform e k3s. Il servizio è finito ed è nel repository, ma la VM non è mai
stata creata: 39 tentativi, sempre "Out of host capacity" nella regione di Milano. Allora ho
rovesciato l'architettura.

Lo stesso codice Java che calcola il verdetto gira **ogni ora in una GitHub Action**: scarica le
previsioni da [Open-Meteo](https://open-meteo.com/) (50 falesie per richiesta),
calcola i tre giorni e scrive un JSON statico, che **GitHub Pages** serve insieme alla pagina. Niente
server e niente database, a costo zero. Intorno:

- una **API statica** versionata, `/api/v1/crags.json` e un file per falesia;
- lo **storico** dei verdetti, un CSV al mese su un branch a parte;
- l'elenco delle falesie che si **riaggiorna da OpenStreetMap** una volta al mese, aprendo una PR
  da rivedere;
- **Lighthouse CI** su ogni PR che tocca la pagina, e un controllo di uptime ogni ora con
  [checkfleet](https://github.com/Allan-Nava/checkfleet) che fallisce anche se i dati sono più
  vecchi di due ore e mezza.

La pagina è in **React e TypeScript**, costruita con Vite: mappa con raggruppamento delle
falesie vicine, ricerca, filtri per verdetto e provincia, ordinamento per distanza (la posizione
non lascia mai il browser) e un pannello per falesia con le ore del giorno in due grafici,
temperatura e pioggia. Il verdetto non si affida mai al solo colore: cerchio S, rombo F,
quadrato N.

## In inverno

D'inverno, per le falesie dentro le zone del bollettino, la pagina mostra anche il **pericolo
valanghe** di ARPA Lombardia: il grado per fascia di quota, i problemi valanghivi e il link al
bollettino ufficiale. Non cambia il verdetto, che riguarda la roccia, ma l'avvicinamento sì.

Il codice è su [GitHub](https://github.com/Allan-Nava/cragcast) (MIT). Se conoscete una
falesia lombarda, aggiungere su OpenStreetMap dove guarda la parete è il contributo che serve di
più.
