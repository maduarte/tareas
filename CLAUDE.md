# CLAUDE.md — Tareas

Contexto para trabajar en este repo. La hoja de ruta está en [PLAN.md](PLAN.md); léela antes de proponer cambios grandes.

## Qué es

PWA de lista de tareas por grupo, con alarmas. La usan 2 o 3 personas cercanas; no guarda datos sensibles. La interfaz es una sola página (`index.html`, JS vanilla, sin build ni dependencias). Se despliega en Vercel desde `main` (push = deploy).

## Estructura

```
index.html          app completa (HTML + CSS + JS)
sw.js               service worker: caché network-first + handler de push
manifest.json       start_url/scope relativos ("./") para servir en cualquier ruta
vercel.json         headers de seguridad (mismo criterio que ../ncs-app)
privacidad.html     qué se guarda y por cuánto tiempo
api/                funciones serverless de Vercel (SIN package.json)
  _store.js         helpers: Upstash REST, validación, secretsMatch, origin
  _vapid.js         firma VAPID (WebCrypto) y envío de push sin payload
  push/key.js       GET  clave pública VAPID
  push/subscribe.js POST guarda la suscripción del dispositivo
  alarms/schedule.js POST programa / DELETE cancela (vía QStash)
  alarms/fire.js    lo llama QStash a la hora: manda el push vacío
  alarms/due.js     lo llama el service worker: devuelve las alarmas que tocan
  cron/queue.js     cron diario: encola en QStash las alarmas que entran en su ventana de 24 h
  _alarms.js        cola de QStash y envío de push compartidos
tools/vapid-keys.mjs  genera las claves VAPID (se corre a mano)
diseno/mockup.html  mockup estático del diseño
```

## Convenciones

- **Sin dependencias npm.** Redis se usa por REST con `fetch` (como `ncs-app`). No agregar `package.json` sin una razón fuerte.
- **Prefijo de claves `tareas:`** en Redis, y solo ese. Nunca `SCAN`/`FLUSH`: la base puede compartirse.
- **QStash es multi-región**: cada cuenta vive en una región y debe usar su URL regional (`QSTASH_URL`); con el endpoint global falla con "user not found in this region".
- **QStash gratuito solo acepta 24 h de retraso.** Las alarmas más lejanas se guardan sin encolar (índice `tareas:pending`) y el cron diario de Vercel las encola. Hobby permite un cron por día, con jitter de hasta una hora: por eso corre a las 07:00 UTC (de madrugada en Chile).
- **Push sin payload**: el service worker pide los títulos a `/api/alarms/due`. Cada push debe terminar en una notificación visible (iOS lo exige).
- Los errores del servidor van a `console.error`; al navegador solo un mensaje genérico.
- El código de dispositivo (`tareas_codigo`, 32 hex) es la única credencial. Se genera en el dispositivo; nunca se muestra ni se registra.
- Al cambiar `sw.js` o la lista de archivos precacheados, subir `CACHE`.

## Datos locales (`localStorage`)

Ver la tabla del [README](README.md). Los completados se borran al terminar el día (a propósito).

## Variables de entorno (Vercel)

Ver [.env.example](.env.example). Nunca poner valores reales en el repo ni en chats.

## Probar

- Interfaz: `python3 -m http.server 8080` y abrir `http://localhost:8080`. Las rutas `/api/*` no existen en ese servidor; la app sigue funcionando y las alarmas con la app cerrada quedan desactivadas.
- API: probada contra Redis y QStash simulados; la prueba real necesita el despliegue con sus variables.
- Alarmas con la app cerrada: solo se verifican en un dispositivo real. En iPhone la app debe estar instalada en la pantalla de inicio (iOS 16.4+).
