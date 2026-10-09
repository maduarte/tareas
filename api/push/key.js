// api/push/key.js
// Clave pública VAPID para que el navegador se suscriba a push.
//
//   GET /api/push/key  → { key }

export default function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const key = process.env.VAPID_PUBLIC_KEY;
  if (!key) return res.status(500).json({ error: 'Push no configurado en el servidor.' });
  res.setHeader('Cache-Control', 'public, max-age=3600');
  return res.status(200).json({ key });
}
