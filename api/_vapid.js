// api/_vapid.js
// Web Push sin librerías: firma VAPID (JWT ES256) con WebCrypto y envío de un
// push SIN payload. Cifrar el payload exigiría aes128gcm a mano o la librería
// web-push; en su lugar el service worker, al recibir el push vacío, pide los
// títulos a /api/alarms/due.
//
// Variables de entorno: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY (ambas base64url),
// VAPID_SUBJECT (mailto:… o https://…). Se generan con tools/vapid-keys.mjs.

const b64u = (buf) => Buffer.from(buf).toString('base64url');
const fromB64u = (s) => Buffer.from(s, 'base64url');

let keyPromise = null;
function signingKey() {
  if (!keyPromise) {
    const pub = fromB64u(process.env.VAPID_PUBLIC_KEY || '');
    if (pub.length !== 65 || pub[0] !== 4) throw new Error('VAPID_PUBLIC_KEY inválida');
    keyPromise = crypto.subtle.importKey(
      'jwk',
      { kty: 'EC', crv: 'P-256', x: b64u(pub.subarray(1, 33)), y: b64u(pub.subarray(33, 65)), d: process.env.VAPID_PRIVATE_KEY, ext: true },
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign']
    );
  }
  return keyPromise;
}

async function vapidHeader(endpoint) {
  const enc = (o) => b64u(JSON.stringify(o));
  const unsigned = enc({ typ: 'JWT', alg: 'ES256' }) + '.' + enc({
    aud: new URL(endpoint).origin,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: process.env.VAPID_SUBJECT || 'mailto:admin@example.com'
  });
  // WebCrypto entrega la firma ECDSA como r||s (64 bytes), el formato de JWT ES256
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, await signingKey(), new TextEncoder().encode(unsigned));
  return `vapid t=${unsigned}.${b64u(sig)}, k=${process.env.VAPID_PUBLIC_KEY}`;
}

// Devuelve el status HTTP del servicio de push (201 = aceptado; 404/410 = la
// suscripción ya no existe y hay que borrarla).
export async function sendPush(endpoint) {
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { Authorization: await vapidHeader(endpoint), TTL: '3600', Urgency: 'high' }
  });
  return res.status;
}

export const vapidConfigured = () => !!(process.env.VAPID_PUBLIC_KEY && process.env.VAPID_PRIVATE_KEY);
