// api/cron/queue.js
// Cron diario de Vercel (ver vercel.json). QStash solo acepta mensajes con
// hasta 24 h de retraso, así que las alarmas más lejanas se guardan sin
// encolar. Cada día este cron encola las que ya entran en la ventana.
//
// También rescata las que quedaron sin encolar y cuya hora ya pasó (el cron de
// Hobby corre con jitter de hasta una hora): manda el push de inmediato.
//
//   GET /api/cron/queue   Authorization: Bearer <CRON_SECRET>  (Vercel lo agrega solo)

import { upstash, cmd, keys, validCode, secretsMatch, origin, parseJSON, fail, noStorage } from '../_store.js';
import { queueAlarm, withinWindow, deliverPush } from '../_alarms.js';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const db = upstash();
  if (!db) return noStorage(res);
  if (!process.env.CRON_SECRET || !process.env.QSTASH_TOKEN || !process.env.ALARM_SECRET) {
    return res.status(500).json({ error: 'Cron no configurado en el servidor.' });
  }
  if (!(await secretsMatch(String(req.headers.authorization || ''), `Bearer ${process.env.CRON_SECRET}`))) {
    return res.status(401).json({ error: 'No autorizado.' });
  }

  const stats = { codes: 0, queued: 0, rescued: 0, waiting: 0 };
  try {
    const codes = (await cmd(db, ['SMEMBERS', keys.pending])) || [];
    for (const code of codes) {
      if (!validCode(code)) { await cmd(db, ['SREM', keys.pending, code]); continue; }
      stats.codes++;
      const key = keys.alarm(code);
      const flat = (await cmd(db, ['HGETALL', key])) || [];
      let waiting = false, needPush = false;

      for (let i = 0; i < flat.length; i += 2) {
        const taskId = flat[i], entry = parseJSON(flat[i + 1]);
        if (!entry || entry.shown || entry.msgId || entry.fired) continue;
        const at = new Date(entry.at).getTime();
        if (at <= Date.now()) {
          entry.fired = true; needPush = true; stats.rescued++;
          await cmd(db, ['HSET', key, taskId, JSON.stringify(entry)]);
        } else if (withinWindow(at)) {
          entry.msgId = await queueAlarm(origin(req), code, taskId, entry);
          stats.queued++;
          await cmd(db, ['HSET', key, taskId, JSON.stringify(entry)]);
        } else {
          waiting = true; stats.waiting++;
        }
      }
      if (needPush) await deliverPush(db, code);
      if (!waiting) await cmd(db, ['SREM', keys.pending, code]);
    }
    return res.status(200).json({ ok: true, ...stats });
  } catch (err) {
    return fail(res, err);
  }
}
