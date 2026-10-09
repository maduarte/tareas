// tools/vapid-keys.mjs
// Genera un par de claves VAPID para Web Push. Se corre a mano, no se despliega:
//
//   node tools/vapid-keys.mjs
//
// Copia los tres valores a Vercel (Settings → Environment Variables). La clave
// privada NO va al repo ni a ningún chat. Cambia VAPID_SUBJECT por un mailto
// tuyo.

const b64u = (buf) => Buffer.from(buf).toString('base64url');

const { privateKey, publicKey } = await crypto.subtle.generateKey(
  { name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']
);
const priv = await crypto.subtle.exportKey('jwk', privateKey);
const raw = new Uint8Array(await crypto.subtle.exportKey('raw', publicKey)); // 0x04 || x || y

console.log('Pega estos valores en las variables de entorno de Vercel:\n');
console.log(`VAPID_PUBLIC_KEY=${b64u(raw)}`);
console.log(`VAPID_PRIVATE_KEY=${priv.d}`);
console.log('VAPID_SUBJECT=mailto:tu-correo@ejemplo.com');
