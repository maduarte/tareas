// api/alarms/fire.js
// Lo llama QStash a la hora de la alarma. Manda un push vacío a cada
// dispositivo del código; el service worker pide después los títulos a
// /api/alarms/due.
//
//   POST /api/alarms/fire   { code, taskId, at }
//   Authorization: Bearer <ALARM_SECRET>   (QStash lo reenvía desde Upstash-Forward-Authorization)

import { upstash, cmd, keys, validCode, validId, normCode, secretsMatch, parseJSON, fail, noStorage } from '../_store.js';
import { vapidConfigured } from '../_vapid.js';
import { deliverPush } from '../_alarms.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const db = upstash();
  if (!db) return noStorage(res);
  if (!vapidConfigured() || !process.env.ALARM_SECRET) {
    return res.status(500).json({ error: 'Push no configurado en el servidor.' });
  }

  const auth = String(req.headers.authorization || '');
  if (!(await secretsMatch(auth, `Bearer ${process.env.ALARM_SECRET}`))) {
    return res.status(401).json({ error: 'No autorizado.' });
  }

  const { code: rawCode, taskId, at } = req.body || {};
  const code = normCode(rawCode);
  if (!validCode(code) || !validId(taskId)) return res.status(400).json({ error: 'Datos inválidos.' });

  try {
    const entry = parseJSON(await cmd(db, ['HGET', keys.alarm(code), taskId]));
    // Cancelada, ya mostrada o reprogramada a otra hora: este mensaje quedó viejo.
    if (!entry || entry.shown || entry.at !== at) return res.status(200).json({ ok: true, skipped: true });

    const delivered = await deliverPush(db, code);
    return res.status(200).json({ ok: true, delivered });
  } catch (err) {
    return fail(res, err);
  }
}
