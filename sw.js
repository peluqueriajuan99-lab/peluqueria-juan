/* Service worker: hace que la app se instale y abra rápido.
   - Archivos propios: primero la red (así siempre ves la versión nueva); sin internet, usa la copia guardada.
   - Librerías externas (QR, Supabase, fuentes): copia guardada + actualización en segundo plano.
   - Supabase (datos, login, imágenes): siempre directo a la red, nunca se guarda. */
const V = 'pelu-v1';
const CORE = ['./', 'index.html', 'config.js', 'manifest.json', 'favicon.svg', 'icon-192.png', 'icon-512.png'];
const CDN = /(^|\.)(cdn\.jsdelivr\.net|cdnjs\.cloudflare\.com|fonts\.googleapis\.com|fonts\.gstatic\.com)$/;

self.addEventListener('install', e => {
  e.waitUntil(caches.open(V).then(c => Promise.allSettled(CORE.map(u => c.add(u)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const r = e.request;
  if (r.method !== 'GET') return;
  const u = new URL(r.url);
  const propio = u.origin === self.location.origin;
  if (!propio && !CDN.test(u.hostname)) return;
  if (propio) {
    const clave = r.mode === 'navigate' ? 'index.html' : r;
    e.respondWith(
      fetch(r).then(res => { if (res.ok) { const cp = res.clone(); caches.open(V).then(c => c.put(clave, cp)); } return res; })
        .catch(() => caches.match(clave).then(m => m || caches.match('index.html')))
    );
  } else {
    e.respondWith(caches.match(r).then(m => {
      const red = fetch(r).then(res => { if (res.ok || res.type === 'opaque') { const cp = res.clone(); caches.open(V).then(c => c.put(r, cp)); } return res; }).catch(() => m);
      return m || red;
    }));
  }
});
