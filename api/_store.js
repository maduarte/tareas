// api/_store.js
// Utilidades compartidas por los endpoints de alarmas y push.
//
// Redis de Upstash vía REST, sin dependencias npm (este repo no tiene
// package.json; mismo criterio que ncs-app).
//
// ── Namespaces ──────────────────────────────────────────────────────────
//   tareas:push:<code>    hash endpoint → JSON de la suscripción push
//   tareas:alarm:<code>   hash taskId → { at, titulo, msgId, shown, fired }
//   tareas:pending        set de códigos con alarmas sin encolar
//
// El <code> (32 hex) lo genera cada dispositivo y es su única credencial:
// quien lo tenga puede ver y programar las alarmas de ese dispositivo. Nada de
// esto sale al cliente salvo lo que devuelve api/alarms/due.
//
// ÚNICO prefijo permitido: "tareas:". Nunca usar SCAN/FLUSH ni comandos que
// recorran la base: puede compartirse con otras apps.

const CODE_RE = /^[a-f0-9]{32}$/;
const ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

// Privacidad: 2 años sin uso → los datos expiran. Cada escritura reinicia la
// cuenta, así que quien use la app no los pierde.
export const TTL = 60 * 60 * 24 * 730;

export const keys = {
  push: (code) => `tareas:push:${code}`,
  alarm: (code) => `tareas:alarm:${code}`,
  // Códigos con alguna alarma guardada pero aún sin encolar en QStash (más
  // lejos que su ventana de 24 h). Lo recorre el cron diario; así no hace
  // falta SCAN sobre toda la base.
  pending: 'tareas:pending'
};

export function upstash() {
  const url = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
  return url && token ? { url: url.replace(/\/$/, ''), token } : null;
}

// Un comando como arreglo: cmd(db, ['HSET', clave, campo, valor]).
// Evita codificar claves y valores en la URL.
export async function cmd(db, args) {
  const res = await fetch(db.url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${db.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(args)
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(json.error || `Upstash ${res.status}`);
  return json.result;
}

export const validCode = (code) => CODE_RE.test(String(code || '').trim().toLowerCase());
export const validId = (id) => ID_RE.test(String(id || ''));
export const normCode = (code) => String(code || '').trim().toLowerCase();

// Origen público de la app. TAREAS_ORIGIN manda en producción (VERCEL_URL
// cambia en cada preview).
export function origin(req) {
  if (process.env.TAREAS_ORIGIN) return process.env.TAREAS_ORIGIN.replace(/\/$/, '');
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  const proto = req.headers['x-forwarded-proto'] || 'https';
  return `${proto}://${host}`;
}

// Compara secretos sin filtrar información por tiempo de respuesta: ambos por
// SHA-256 primero, así el largo nunca difiere.
export async function secretsMatch(a, b) {
  if (!a || !b) return false;
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(String(a))),
    crypto.subtle.digest('SHA-256', enc.encode(String(b)))
  ]);
  const x = new Uint8Array(ha), y = new Uint8Array(hb);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export function parseJSON(raw) {
  try { return typeof raw === 'string' ? JSON.parse(raw) : raw; } catch (e) { return null; }
}

// El detalle va al log y no al navegador: el mensaje de Upstash puede traer
// nombres de clave y de servidor.
export function fail(res, err, status = 502, msg = 'No se pudo completar la operación. Reintenta en un momento.') {
  console.error('tareas api error', err);
  return res.status(status).json({ error: msg });
}

export function noStorage(res) {
  return res.status(500).json({ error: 'Almacenamiento no configurado en el servidor.' });
}
