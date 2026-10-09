// Subir el número de CACHE cuando cambie la lista de archivos o su estrategia.
const CACHE = 'tareas-v4';
const FILES = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  // 'tareas-meta' guarda el código del dispositivo para el push: no se borra
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE && k !== 'tareas-meta').map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

// Network-first: siempre intenta la red (así se ven los cambios al instante) y
// guarda la respuesta; sin red, responde desde la caché.
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok) {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
      }
      return res;
    }).catch(() => caches.match(req, { ignoreSearch: true }).then(hit => hit || caches.match('./index.html')))
  );
});

// Push vacío desde el servidor: pedir qué alarmas tocan y mostrarlas. Cada push
// debe terminar en una notificación visible (iOS lo exige).
self.addEventListener('push', e => {
  e.waitUntil((async () => {
    let alarms = null;
    try {
      const meta = await caches.open('tareas-meta');
      const hit = await meta.match('/__code');
      const code = hit ? await hit.text() : null;
      if (code) {
        const res = await fetch('/api/alarms/due?code=' + encodeURIComponent(code), { cache: 'no-store' });
        if (res.ok) alarms = (await res.json()).alarms;
      }
    } catch (_) {}
    if (alarms && alarms.length) {
      await Promise.all(alarms.map(a =>
        self.registration.showNotification('⏰ ' + a.titulo, { tag: 'tarea-' + a.taskId })));
      return;
    }
    // Sin títulos: o falló la consulta, o la alarma ya se mostró (la app abierta
    // la mostró antes, o llegó un push repetido). Si hay una alarma visible no se
    // agrega una genérica; si no hay ninguna, sí, porque cada push debe terminar
    // en una notificación (iOS lo exige).
    const visibles = await self.registration.getNotifications();
    if (!visibles.some(n => (n.tag || '').startsWith('tarea-'))) {
      await self.registration.showNotification('⏰ Tienes una alarma', { tag: 'tarea-generica' });
    }
  })());
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow('./');
    })
  );
});
