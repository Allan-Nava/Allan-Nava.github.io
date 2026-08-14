---
layout: null
permalink: /sw.js
---
/*
 * Service worker (#139) — sito installabile e leggibile offline.
 *
 * Sta alla radice perché lo scope di un service worker non può salire sopra la
 * propria cartella: da /assets/sw.js non potrebbe controllare /blog/.
 *
 * PRINCIPIO: la freschezza viene dalla rete, non dall'invalidazione della cache.
 * L'HTML è sempre network-first, quindi un post aggiornato si vede al primo
 * caricamento online. In cache finisce solo ciò che è di fatto immutabile
 * (font, icone) o rigenerabile senza danni (immagini, stale-while-revalidate).
 * Per questo il nome della cache NON è versionato per build: il cron
 * ricostruisce il sito ogni giorno e un nome versionato svuoterebbe la cache
 * offline di tutti, ogni giorno, senza motivo.
 *
 * PER DISATTIVARLO: sostituire il contenuto di questo file con
 *     self.addEventListener('install', () => self.skipWaiting());
 *     self.addEventListener('activate', (e) => e.waitUntil(
 *       caches.keys().then((k) => Promise.all(k.map((n) => caches.delete(n))))
 *         .then(() => self.registration.unregister())
 *     ));
 * e deployare: i browser che lo hanno installato si ripuliscono da soli. Non
 * basta cancellare il file — chi lo ha già installato continuerebbe a usarlo.
 *
 * Alzare CACHE quando cambia la strategia (non a ogni contenuto).
 */
var CACHE = 'allan-nava-v1';
var OFFLINE_URL = '/offline/';

/* Il guscio minimo per rispondere qualcosa da offline. Volutamente corto:
   precaricare le 335 pagine sarebbe decine di MB nella cache del visitatore. */
var PRECACHE = [
  OFFLINE_URL,
  '/assets/fonts/inter-latin-wght-normal.woff2',
  '/assets/images/pwa/icon-192.png'
];

/* Rigenerati a ogni build: dalla cache servirebbero risultati di ricerca e feed
   vecchi, che è peggio di un errore di rete. */
var NEVER_CACHE = ['/search.json', '/feed.xml', '/sitemap.xml', '/robots.txt'];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE)
      .then(function (cache) { return cache.addAll(PRECACHE); })
      /* Se una risorsa del guscio manca, l'install non deve fallire: il SW
         resterebbe non installato e non ci sarebbe alcun offline. */
      .catch(function () { return null; })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (names) {
        return Promise.all(names.map(function (n) {
          return n === CACHE ? null : caches.delete(n);
        }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

function isNeverCache(url) {
  for (var i = 0; i < NEVER_CACHE.length; i++) {
    if (url.pathname === NEVER_CACHE[i]) return true;
  }
  return false;
}

/* Cache-first: font e icone non cambiano mai sotto lo stesso nome. */
function cacheFirst(request) {
  return caches.match(request).then(function (hit) {
    if (hit) return hit;
    return fetch(request).then(function (res) {
      if (res && res.ok) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put(request, copy); });
      }
      return res;
    });
  });
}

/* Stale-while-revalidate: le immagini si vedono subito dalla cache e si
   aggiornano in background, così un file sostituito a parità di nome si
   sistema al giro dopo invece di restare vecchio per sempre. */
function staleWhileRevalidate(request) {
  return caches.match(request).then(function (hit) {
    var network = fetch(request).then(function (res) {
      if (res && res.ok) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put(request, copy); });
      }
      return res;
    }).catch(function () { return hit; });
    return hit || network;
  });
}

/* Network-first per l'HTML: online si vede sempre l'ultima versione, offline si
   ripiega sulla copia dell'ultima visita e, se non c'è, sulla pagina offline. */
function networkFirst(request) {
  return fetch(request).then(function (res) {
    if (res && res.ok) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(request, copy); });
    }
    return res;
  }).catch(function () {
    return caches.match(request).then(function (hit) {
      return hit || caches.match(OFFLINE_URL);
    });
  });
}

self.addEventListener('fetch', function (event) {
  var request = event.request;

  if (request.method !== 'GET') return;

  var url;
  try {
    url = new URL(request.url);
  } catch (e) {
    return;
  }

  /* Solo same-origin: le thumbnail YouTube (i.ytimg.com) restano alla rete e al
     suo caching, non le mettiamo nella cache del sito. */
  if (url.origin !== self.location.origin) return;
  if (isNeverCache(url)) return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request));
    return;
  }

  if (url.pathname.indexOf('/assets/fonts/') === 0 ||
      url.pathname.indexOf('/assets/images/pwa/') === 0 ||
      url.pathname.indexOf('/assets/images/favicon/') === 0) {
    event.respondWith(cacheFirst(request));
    return;
  }

  if (url.pathname.indexOf('/assets/images/') === 0) {
    event.respondWith(staleWhileRevalidate(request));
  }
});
