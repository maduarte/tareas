// api/snapshot.js
// Instantánea de solo lectura de la lista de HOY, para el widget del Mac.
//
//   POST   /api/snapshot  { code, fecha, nombre, acento, items:[{titulo,grupo,color,urgencia,plazo,alarma}], proximos:[{…, dia}] }  → { ok }
//   GET    /api/snapshot?token=<64hex>   → { at, fecha, items }   (404 si no hay)
//   DELETE /api/snapshot?code=<32hex>    → { ok }
//
// El celular escribe con su código; el widget lee con el token de solo lectura
// derivado de ese código (ver readToken en _store.js). La instantánea se guarda
// bajo el token, así que el código nunca sale del dispositivo ni de este archivo.

import { upstash, cmd, keys, validCode, normCode, validToken, readToken, parseJSON, fail, noStorage } from './_store.js';

const TTL_SNAP = 60 * 60 * 24 * 30; // sin actualizarse en 30 días, se borra
const MAX_ITEMS = 100;
const URGENCIAS = new Set(['alta', 'media', 'baja']);
const FECHA_RE = /^\d{4}-\d{2}-\d{2}$/;
const HEX_RE = /^#[0-9a-fA-F]{6}$/;
const isoOrNull = (v) => (typeof v === 'string' && Number.isFinite(new Date(v).getTime()) ? new Date(v).toISOString() : null);

function cleanItems(raw) {
  if (!Array.isArray(raw) || raw.length > MAX_ITEMS) return null;
  const out = [];
  for (const it of raw) {
    if (!it || typeof it.titulo !== 'string' || !it.titulo.trim()) return null;
    out.push({
      titulo: it.titulo.trim().slice(0, 200),
      grupo: typeof it.grupo === 'string' ? it.grupo.trim().slice(0, 60) : '',
      color: HEX_RE.test(it.color) ? it.color : null,
      urgencia: URGENCIAS.has(it.urgencia) ? it.urgencia : null,
      plazo: isoOrNull(it.plazo),
      alarma: isoOrNull(it.alarma),
      dia: FECHA_RE.test(it.dia) ? it.dia : null
    });
  }
  return out;
}

export default async function handler(req, res) {
  const db = upstash();
  if (!db) return noStorage(res);
  res.setHeader('Cache-Control', 'no-store');

  try {
    if (req.method === 'GET') {
      const token = String(req.query?.token || '').trim().toLowerCase();
      if (!validToken(token)) return res.status(400).json({ error: 'Token inválido.' });
      const snap = parseJSON(await cmd(db, ['GET', keys.snap(token)]));
      if (!snap) return res.status(404).json({ error: 'Sin datos.' });
      return res.status(200).json(snap);
    }

    if (req.method === 'DELETE') {
      const code = normCode(req.query?.code);
      if (!validCode(code)) return res.status(400).json({ error: 'Código inválido.' });
      await cmd(db, ['DEL', keys.snap(await readToken(code))]);
      return res.status(200).json({ ok: true });
    }

    if (req.method !== 'POST') {
      res.setHeader('Allow', 'GET, POST, DELETE');
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const { code: rawCode, fecha, nombre, acento, items: rawItems, proximos: rawProx } = req.body || {};
    const code = normCode(rawCode);
    const items = cleanItems(rawItems);
    const proximos = rawProx === undefined ? [] : cleanItems(rawProx);
    if (!validCode(code) || !FECHA_RE.test(String(fecha || '')) || !items || !proximos) {
      return res.status(400).json({ error: 'Datos inválidos.' });
    }
    const snap = {
      at: new Date().toISOString(), fecha, items, proximos,
      nombre: typeof nombre === 'string' ? nombre.trim().slice(0, 40) : '',
      acento: HEX_RE.test(acento) ? acento : null
    };
    await cmd(db, ['SET', keys.snap(await readToken(code)), JSON.stringify(snap), 'EX', TTL_SNAP]);
    return res.status(200).json({ ok: true });
  } catch (err) {
    return fail(res, err);
  }
}
