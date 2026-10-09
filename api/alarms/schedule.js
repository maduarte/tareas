// api/alarms/schedule.js
// Programa o cancela la alarma de una tarea.
//
//   POST   /api/alarms/schedule  { code, taskId, titulo, at }  → { ok, queued }
//   DELETE /api/alarms/schedule?code=<32hex>&taskId=<id>       → { ok }
//
// La entrega la hace QStash: llama a /api/alarms/fire a la hora exacta, sin
// cron ni sondeo. `queued:false` significa que la alarma quedó guardada pero
// más lejos que el retraso máximo de QStash; el cliente la vuelve a enviar
// más cerca de la fecha.

import { upstash, cmd, keys, TTL, validCode, validId, normCode, origin, parseJSON, fail, noStorage } from '../_store.js';

const QSTASH = 'https://qstash.upstash.io/v2';
const MAX_ALARMS = 200;
const MAX_DELAY_DAYS = Number(process.env.QSTASH_MAX_DELAY_DAYS) || 7;

async function qstash(path, init = {}) {
  const res = await fetch(`${QSTASH}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${process.env.QSTASH_TOKEN}`, ...(init.headers || {}) }
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(json.error || `QStash ${res.status}`);
  return json;
}

async function cancelMessage(entry) {
  if (!entry || !entry.msgId) return;
  try { await qstash(`/messages/${entry.msgId}`, { method: 'DELETE' }); } catch (e) { /* ya entregado o inexistente */ }
}

export default async function handler(req, res) {
  const db = upstash();
  if (!db) return noStorage(res);
  if (!process.env.QSTASH_TOKEN || !process.env.ALARM_SECRET) {
    return res.status(500).json({ error: 'Alarmas no configuradas en el servidor.' });
  }

  try {
    if (req.method === 'DELETE') {
      const code = normCode(req.query?.code), taskId = String(req.query?.taskId || '');
      if (!validCode(code) || !validId(taskId)) return res.status(400).json({ error: 'Datos inválidos.' });
      const key = keys.alarm(code);
      await cancelMessage(parseJSON(await cmd(db, ['HGET', key, taskId])));
      await cmd(db, ['HDEL', key, taskId]);
      return res.status(200).json({ ok: true });
    }

    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST, DELETE');
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const { code: rawCode, taskId, titulo, at } = req.body || {};
    const code = normCode(rawCode);
    const when = new Date(at).getTime();
    if (!validCode(code) || !validId(taskId) || typeof titulo !== 'string' || !titulo.trim() || !Number.isFinite(when)) {
      return res.status(400).json({ error: 'Datos inválidos.' });
    }
    if (when <= Date.now()) return res.status(400).json({ error: 'La alarma ya pasó.' });

    const key = keys.alarm(code);
    const previous = parseJSON(await cmd(db, ['HGET', key, taskId]));
    if (!previous && (await cmd(db, ['HLEN', key])) >= MAX_ALARMS) {
      return res.status(409).json({ error: 'Demasiadas alarmas pendientes.' });
    }
    await cancelMessage(previous);

    const entry = { at: new Date(when).toISOString(), titulo: titulo.trim().slice(0, 200), msgId: null, shown: false };
    const queued = when - Date.now() <= MAX_DELAY_DAYS * 864e5;
    if (queued) {
      const sent = await qstash(`/publish/${origin(req)}/api/alarms/fire`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Upstash-Not-Before': String(Math.floor(when / 1000)),
          'Upstash-Retries': '2',
          'Upstash-Forward-Authorization': `Bearer ${process.env.ALARM_SECRET}`
        },
        body: JSON.stringify({ code, taskId, at: entry.at })
      });
      entry.msgId = sent.messageId || null;
    }
    await cmd(db, ['HSET', key, taskId, JSON.stringify(entry)]);
    await cmd(db, ['EXPIRE', key, TTL]);
    return res.status(200).json({ ok: true, queued });
  } catch (err) {
    return fail(res, err);
  }
}
