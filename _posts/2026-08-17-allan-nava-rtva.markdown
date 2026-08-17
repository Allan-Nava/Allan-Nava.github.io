---
title: "RTVA — Ràdio i Televisió d'Andorra"
layout: post
date: 2026-08-17 09:30
tag:
- site
- web
- ott
- streaming
- nextjs
- golang
- hiway media
- hiway
- rtva
image: ""
headerImage: false
projects: true
hidden: true # don't count this post in blog pagination
description: "Il portale della TV pubblica andorrana: diretta dei canali, on demand e informazione, per il pubblico di Andorra, Spagna e Francia."
category: project
author: allan
---

Portale della **televisione pubblica di Andorra** (Ràdio i Televisió d'Andorra): diretta dei
canali, archivio on demand, informazione e servizio pubblico su `rtva.ad`, più il casting verso
TV e set-top box su `cast.rtva.media`. Il pubblico è quello del Principato e delle zone di
confine — Andorra, Spagna e Francia.

## Com'è fatto

Stessa piattaforma degli altri progetti video: frontend **Next.js** server-side, backend **Go**,
dati replicati e distribuzione **multi-region** dietro CDN.

Quello che cambia, rispetto a un sito di calcio, è il profilo: qui **non c'è la partita**. Non
esiste il picco da evento su cui puntare tutto — c'è un flusso quotidiano continuo, legato ai
telegiornali e alla programmazione, che va letto come **serie storica** invece che come singolo
scatto. Un dettaglio banale a dirsi che però ribalta il modo di misurare capacità e regressioni.

## Cosa faccio io

Lato infrastruttura: profilo di traffico giornaliero (quanta parte è pubblico reale e quanta
bot/probe), analisi di capacità, e monitoring continuo dell'ingress e dei layer applicativi.

<div class="side-by-side">
    <div class="toleft">
        <figcaption class="caption">RTVA — Ràdio i Televisió d'Andorra</figcaption>
    </div>

    <div class="toright">
        <p></p>
        <p><a href="https://rtva.ad" target="_blank" rel="noopener">https://rtva.ad</a></p>
        <p><a href="https://cast.rtva.media" target="_blank" rel="noopener">https://cast.rtva.media</a></p>
    </div>
</div>
