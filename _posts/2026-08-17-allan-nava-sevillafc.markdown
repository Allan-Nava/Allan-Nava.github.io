---
title: "Sevilla FC"
layout: post
date: 2026-08-17 09:00
tag:
- site
- web
- ott
- streaming
- nextjs
- golang
- hiway media
- hiway
- sevillafc
image: ""
headerImage: false
projects: true
hidden: true # don't count this post in blog pagination
description: "Sito ufficiale e TV del Sevilla FC: news, dirette e on demand per i tifosi del club andaluso, su piattaforma multi-region."
category: project
author: allan
---

Sito ufficiale e piattaforma video del **Sevilla FC**, il club di Siviglia: news e contenuti
editoriali su `sevillafc.es`, la TV del club su `tv.sevillafc.es` con dirette e on demand, e il
casting verso TV e set-top box su `cast.sevillafc.es`.

## Com'è fatto

Frontend **Next.js** con rendering server-side, backend **Go**, database replicato e ricerca
dedicata: il tutto girando in **multi-region attiva** su tre datacenter, con una **CDN davanti**
che assorbe la parte statica e serve i tifosi vicino a casa loro.

La differenza rispetto a un sito editoriale normale è la **forma del carico**: fra una partita e
l'altra il traffico è piatto, poi nel giorno del match si concentra tutto in una manciata di ore
attorno al fischio d'inizio. È lì che il sito va dimensionato, non sulla media.

## Cosa faccio io

Sto sul lato **infrastruttura e affidabilità**: profilo di traffico giornaliero, analisi per
singolo evento live (quanti utenti reali, quali chiamate, dove si accumula la latenza), capacity
planning sui picchi da partita e health check continui sull'ingress.

<div class="side-by-side">
    <div class="toleft">
        <figcaption class="caption">Sevilla FC — sito ufficiale e TV del club</figcaption>
    </div>

    <div class="toright">
        <p></p>
        <p><a href="https://sevillafc.es" target="_blank" rel="noopener">https://sevillafc.es</a></p>
        <p><a href="https://tv.sevillafc.es" target="_blank" rel="noopener">https://tv.sevillafc.es</a></p>
    </div>
</div>
