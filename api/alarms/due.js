// api/alarms/due.js
// Lo llama el service worker al recibir un push: devuelve las alarmas cuya
// hora ya llegó y aún no se mostraron, y las marca como mostradas.
//
//   GET /api/alarms/due?code=<32hex>  → { alarms: [{ taskId, titulo }] }

import { upstash, cmd, keys, validCode, normCode, parseJSON, fail, noStorage } from '../_store.js';

const TOLERANCIA_MS = 30 * 1000;   // el push puede llegar un poco antes que la hora exacta
const RETENCION_MS = 2 * 864e5;    // las ya mostradas se limpian a los 2 días

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const db = upstash();
  if (!db) return noStorage(res);

  const code = normCode(req.query?.code);
  if (!validCode(code)) return res.status(400).json({ error: 'Código inválido.' });

  try {
    const key = keys.alarm(code);
    const flat = await cmd(db, ['HGETALL', key]);
    const now = Date.now();
    const out = [];
    for (let i = 0; Array.isArray(flat) && i < flat.length; i += 2) {
      const taskId = flat[i], entry = parseJSON(flat[i + 1]);
      if (!entry) continue;
      const at = new Date(entry.at).getTime();
      if (entry.shown) {
        if (now - at > RETENCION_MS) await cmd(db, ['HDEL', key, taskId]);
      } else if (at <= now + TOLERANCIA_MS) {
        out.push({ taskId, titulo: entry.titulo });
        await cmd(db, ['HSET', key, taskId, JSON.stringify({ ...entry, shown: true })]);
      }
    }
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json({ alarms: out });
  } catch (err) {
    return fail(res, err);
  }
}
