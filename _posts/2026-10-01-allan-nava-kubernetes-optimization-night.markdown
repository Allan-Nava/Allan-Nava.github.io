---
title: "Kubernetes Optimization Night, Akamas e AWS a Milano"
layout: post
date: 2026-10-01 21:00
tag:
- kubernetes
- aws
- nomad
- event
- milan
image: ""
headerImage: false
description: "Appunti dalla prima Kubernetes Optimization Night di Akamas e AWS a Milano: cluster sottoutilizzati, ottimizzazione full-stack, e cosa vale anche per chi usa Nomad."
category: blog
author: allan
lang: it
locale: it_IT
---

Il 1° ottobre sono stato alla prima **[Kubernetes Optimization Night](https://akamas.io/events/kubernetes-optimization-night/)**,
organizzata da **Akamas** e **AWS** nell'ufficio AWS di Viale Monte Grappa a Milano. Sala piena.

## I talk

- **Marco De Bianchi** (AWS) — *Introduction to Amazon EKS and efficient scaling with Auto Mode*:
  come EKS adatta la capacità del cluster al carico.
- **Stefano Doni** (CTO di Akamas) — *Squeezing the cluster: full-stack K8s resource optimization*,
  con una demo dal vivo.

## Cosa mi porto a casa

Il punto di Stefano Doni, da quello che Akamas vede su centinaia di cluster: la maggior parte dei
cluster reali gira **molto sottoutilizzata** e nonostante questo sbatte comunque contro limiti di
performance e affidabilità. La soluzione non è una leva sola ma **full-stack**: requests e limits dei
pod, autoscaling, le impostazioni del runtime (JVM, Node.js), fino alla scelta del tipo di istanza
dei nodi.

## Perché mi riguarda anche senza Kubernetes

Le piattaforme video live su cui lavoro girano su **Nomad**, non su Kubernetes, ma il problema è lo
stesso: le risorse si dichiarano per job, il traffico arriva tutto insieme nel giorno della partita,
e la tentazione è sovradimensionare "per sicurezza". Dimensionare per il picco senza pagarlo il resto
della settimana è buona parte del lavoro.

Grazie ad Akamas e AWS per la serata.
