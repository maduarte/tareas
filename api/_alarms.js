// api/_alarms.js
// Lógica compartida de alarmas: cola de QStash y envío de push.
//
// QStash (plan gratuito) solo acepta mensajes con hasta 24 h de retraso. Una
// alarma más lejana se guarda sin encolar (msgId null) y el cron diario
// (api/cron/queue.js) la encola cuando entra en la ventana. Para que un cron
// que corre con unos minutos de jitter no deje huecos, el margen es de 1 h.

import { cmd, keys, parseJSON } from './_store.js';
import { sendPush } from './_vapid.js';

const QSTASH = 'https://qstash.upstash.io/v2';
const MAX_HOURS = Number(process.env.QSTASH_MAX_DELAY_HOURS) || 24;
export const WINDOW_MS = Math.max(1, MAX_HOURS - 1) * 3600e3;

export const withinWindow = (atMs) => atMs - Date.now() <= WINDOW_MS;

async function qstash(path, init = {}) {
  const res = await fetch(`${QSTASH}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${process.env.QSTASH_TOKEN}`, ...(init.headers || {}) }
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(json.error || `QStash ${res.status}`);
  return json;
}

export async function cancelMessage(entry) {
  if (!entry || !entry.msgId) return;
  try { await qstash(`/messages/${entry.msgId}`, { method: 'DELETE' }); } catch (e) { /* ya entregado o inexistente */ }
}

// Pide a QStash que llame a /api/alarms/fire a la hora de la alarma.
export async function queueAlarm(origin, code, taskId, entry) {
  const sent = await qstash(`/publish/${origin}/api/alarms/fire`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Upstash-Not-Before': String(Math.floor(new Date(entry.at).getTime() / 1000)),
      'Upstash-Retries': '2',
      'Upstash-Forward-Authorization': `Bearer ${process.env.ALARM_SECRET}`
    },
    body: JSON.stringify({ code, taskId, at: entry.at })
  });
  return sent.messageId || null;
}

// Manda un push vacío a cada dispositivo del código y limpia los que ya no existen.
export async function deliverPush(db, code) {
  const pushKey = keys.push(code);
  const endpoints = (await cmd(db, ['HKEYS', pushKey])) || [];
  let delivered = 0;
  for (const endpoint of endpoints) {
    const status = await sendPush(endpoint);
    if (status === 404 || status === 410) await cmd(db, ['HDEL', pushKey, endpoint]);
    else if (status >= 200 && status < 300) delivered++;
    else console.error('push rechazado', status, new URL(endpoint).origin);
  }
  return delivered;
}

export { parseJSON };
