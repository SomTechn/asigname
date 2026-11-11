// Asígname · service worker: abre sin conexión, se actualiza solo y muestra notificaciones.
const CACHE = 'asigname-v2';
const BASE = ['./', 'asigname.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-180.png', 'icon-32.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(BASE.map(u => c.add(u).catch(() => { })))).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.hostname.endsWith('supabase.co') || u.hostname.endsWith('openstreetmap.org') || u.pathname.endsWith('version.json')) return;
  if (e.request.mode === 'navigate') {
    e.respondWith(fetch(e.request, { cache: 'no-cache' }).then(r => { if (r.ok) { const c = r.clone(); caches.open(CACHE).then(x => x.put('./', c)); } return r; }).catch(() => caches.match('./')));
    return;
  }
  e.respondWith(caches.match(e.request).then(m => {
    const red = fetch(e.request).then(r => { if (r.ok || r.type === 'opaque') { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); } return r; }).catch(() => m);
    return m || red;
  }));
});
self.addEventListener('push', e => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch (_) { d = { title: 'Asígname', body: e.data ? e.data.text() : '' }; }
  e.waitUntil((async () => {
    // si la app está abierta y visible en ese mismo chat, no molestar
    const ws = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (ws.some(w => w.visibilityState === 'visible' && w.focused && d.url && w.url.endsWith(d.url))) return;
    await self.registration.showNotification(d.title || 'Asígname', {
      body: d.body || '', icon: 'icon-192.png', badge: 'icon-badge.png', tag: d.tag || undefined, renotify: !!d.tag,
      data: { url: d.url || '#/' }, vibrate: [80, 40, 80],
    });
  })());
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = e.notification.data?.url || '#/';
  const destino = new URL('./' + url, self.registration.scope).href;
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(ws => {
    const w = ws.find(x => x.url.startsWith(self.registration.scope));
    if (w) { w.postMessage({ url }); return w.focus(); }
    return clients.openWindow(destino);
  }));
});
