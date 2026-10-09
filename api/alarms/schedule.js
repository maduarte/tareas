// api/alarms/schedule.js
// Programa o cancela la alarma de una tarea.
//
//   POST   /api/alarms/schedule  { code, taskId, titulo, at }  → { ok, queued }
//   DELETE /api/alarms/schedule?code=<32hex>&taskId=<id>       → { ok }
//
// La entrega la hace QStash: llama a /api/alarms/fire a la hora exacta, sin
// sondeo. QStash solo acepta hasta 24 h de retraso, así que una alarma más
// lejana queda guardada con `queued:false` y el cron diario (api/cron/queue.js)
// la encola cuando entra en la ventana. El cliente también la reenvía al
// acercarse la fecha.

import { upstash, cmd, keys, TTL, validCode, validId, normCode, origin, parseJSON, fail, noStorage } from '../_store.js';
import { cancelMessage, queueAlarm, withinWindow } from '../_alarms.js';

const MAX_ALARMS = 200;

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
    const queued = withinWindow(when);
    if (queued) entry.msgId = await queueAlarm(origin(req), code, taskId, entry);
    else await cmd(db, ['SADD', keys.pending, code]);
    await cmd(db, ['HSET', key, taskId, JSON.stringify(entry)]);
    await cmd(db, ['EXPIRE', key, TTL]);
    return res.status(200).json({ ok: true, queued });
  } catch (err) {
    return fail(res, err);
  }
}
