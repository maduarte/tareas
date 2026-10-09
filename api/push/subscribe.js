// api/push/subscribe.js
// Guarda la suscripción push de un dispositivo.
//
//   POST /api/push/subscribe   { code, subscription: { endpoint, … } }
//
// Como el push va sin payload, solo hace falta el endpoint.

import { upstash, cmd, keys, TTL, validCode, normCode, fail, noStorage } from '../_store.js';

const MAX_SUBS = 10; // dispositivos por código

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const db = upstash();
  if (!db) return noStorage(res);

  const { code: rawCode, subscription } = req.body || {};
  if (!validCode(rawCode)) return res.status(400).json({ error: 'Código inválido.' });
  const endpoint = subscription && subscription.endpoint;
  if (typeof endpoint !== 'string' || !/^https:\/\//.test(endpoint) || endpoint.length > 1000) {
    return res.status(400).json({ error: 'Suscripción inválida.' });
  }
  const key = keys.push(normCode(rawCode));

  try {
    const existing = await cmd(db, ['HLEN', key]);
    const known = await cmd(db, ['HEXISTS', key, endpoint]);
    if (!known && existing >= MAX_SUBS) {
      return res.status(409).json({ error: 'Demasiados dispositivos para este código.' });
    }
    await cmd(db, ['HSET', key, endpoint, JSON.stringify({ at: Date.now() })]);
    await cmd(db, ['EXPIRE', key, TTL]);
    return res.status(200).json({ ok: true });
  } catch (err) {
    return fail(res, err);
  }
}
