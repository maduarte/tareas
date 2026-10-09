// Subir el número de CACHE cuando cambie la lista de archivos o su estrategia.
const CACHE = 'tareas-v5';
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
        self.registration.showNotification('⏰ ' + a.titulo, alarmOptions(a.taskId, a.titulo))));
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

// Opciones comunes de una notificación de alarma. El sonido lo decide el sistema
// (ajustes de notificaciones del teléfono); desde la web solo se controla la
// vibración (Android) y que no se cierre sola (escritorio). Los botones de
// acción no existen en iOS: allí queda la hoja que se abre al tocar.
function alarmOptions(taskId, titulo) {
  return {
    tag: 'tarea-' + taskId,
    data: { taskId, titulo },
    actions: [{ action: 'snooze10', title: 'Posponer 10 min' }],
    vibrate: [200, 100, 200, 100, 200],
    requireInteraction: true
  };
}

const POSPONER_MS = 10 * 60 * 1000;

// Pospone desde el botón con la app cerrada: reprograma en el servidor y deja
// anotado en 'tareas-meta' para que la app lo aplique a la tarea al abrirse.
async function posponer(data) {
  const meta = await caches.open('tareas-meta');
  const hit = await meta.match('/__code');
  const code = hit ? await hit.text() : null;
  const at = new Date(Date.now() + POSPONER_MS).toISOString();
  let ok = false;
  try {
    if (code) {
      const res = await fetch('/api/alarms/schedule', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code, taskId: data.taskId, titulo: data.titulo, at })
      });
      ok = res.ok;
    }
  } catch (_) {}
  if (!ok) {
    await self.registration.showNotification('No se pudo posponer', { body: data.titulo, tag: 'tarea-' + data.taskId });
    return;
  }
  const prev = await meta.match('/__snooze');
  const list = prev ? await prev.json() : [];
  list.push({ taskId: data.taskId, at });
  await meta.put('/__snooze', new Response(JSON.stringify(list)));
}

self.addEventListener('notificationclick', e => {
  const data = e.notification.data || {};
  e.notification.close();
  if (e.action === 'snooze10' && data.taskId) { e.waitUntil(posponer(data)); return; }
  e.waitUntil((async () => {
    const list = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of list) {
      if ('focus' in client) {
        if (data.taskId) client.postMessage({ type: 'alarma', taskId: data.taskId });
        return client.focus();
      }
    }
    if (self.clients.openWindow) {
      return self.clients.openWindow(data.taskId ? './?alarma=' + encodeURIComponent(data.taskId) : './');
    }
  })());
});
