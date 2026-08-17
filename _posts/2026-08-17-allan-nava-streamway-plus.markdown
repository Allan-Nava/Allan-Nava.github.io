---
title: "Streamway Plus"
layout: post
date: 2026-08-17 09:40
tag:
- site
- web
- ott
- streaming
- nextjs
- golang
- hiway media
- hiway
- streamway
image: ""
headerImage: false
projects: true
hidden: true # don't count this post in blog pagination
description: "Streamway Plus: piattaforma OTT con dirette, on demand e area utenti, distribuita su più datacenter dietro CDN."
category: project
author: allan
---

**Streamway Plus** è la piattaforma OTT del gruppo: dirette, catalogo on demand e area utenti
con registrazione e contenuti riservati, su `streamwayplus.com` e `tv.streamwayplus.com`.

## Com'è fatto

Frontend **Next.js** con rendering server-side, backend **Go**, database replicato e
distribuzione **multi-region** su più datacenter, con CDN davanti alla parte statica e
autenticazione centralizzata per l'area utenti.

Nata come prodotto interno e diventata poi un brand a sé, Streamway è il progetto su cui
sperimentiamo per primi le modifiche alla distribuzione: quello che funziona qui viene poi
portato sugli altri tenant.

## Cosa faccio io

Lato infrastruttura e affidabilità: monitoring dell'ingress, health check periodici,
verifica della catena CDN → origin e analisi del carico quando il traffico cambia forma.

<div class="side-by-side">
    <div class="toleft">
        <figcaption class="caption">Streamway Plus</figcaption>
    </div>

    <div class="toright">
        <p></p>
        <p><a href="https://streamwayplus.com" target="_blank" rel="noopener">https://streamwayplus.com</a></p>
        <p><a href="https://tv.streamwayplus.com" target="_blank" rel="noopener">https://tv.streamwayplus.com</a></p>
    </div>
</div>
