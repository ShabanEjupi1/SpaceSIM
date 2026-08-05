#!/usr/bin/env node
// Dump i papërpunuar i një gjurme (track) — për të parë `countryTargeting`,
// `userFraction` dhe çdo fushë që `gjendja` e përmbledh.
//
//   node gjurma-raw.mjs <çelësi.json> <paketa> [gjurma…]
//
// 🚨 Play Console e ankohet «No countries or regions have been selected for this
//    track» kur lëshimi i gjurmës nuk ka as `countryTargeting.countries` as
//    `includeRestOfWorld: true`. Ajo fushë NUK duket te `tracks.list` i
//    përmbledhur, ndaj ky dump është mënyra e vetme për ta parë.

import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const [keyPath, pkg, ...gjurmet] = process.argv.slice(2);
if (!keyPath || !pkg) {
  console.error('përdorimi: gjurma-raw.mjs <çelësi.json> <paketa> [gjurma…]');
  process.exit(2);
}

const key = JSON.parse(readFileSync(keyPath, 'utf8'));
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');

async function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'RS256', typ: 'JWT' });
  const body = b64({
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const sig = createSign('RSA-SHA256').update(`${head}.${body}`).end().sign(key.private_key, 'base64url');
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${head}.${body}.${sig}`,
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`oauth ${r.status}: ${JSON.stringify(j)}`);
  return j.access_token;
}

const tok = await token();
const call = async (url) => {
  const r = await fetch(url, { headers: { authorization: `Bearer ${tok}` } });
  const t = await r.text();
  if (!r.ok) throw new Error(`${r.status} ${url}\n${t}`);
  return t ? JSON.parse(t) : {};
};

const edit = await fetch(`${API}/${pkg}/edits`, {
  method: 'POST',
  headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
  body: '{}',
}).then((r) => r.json());

const lista = gjurmet.length
  ? { tracks: gjurmet.map((t) => ({ track: t })) }
  : await call(`${API}/${pkg}/edits/${edit.id}/tracks`);

for (const t of lista.tracks ?? []) {
  const plot = await call(`${API}/${pkg}/edits/${edit.id}/tracks/${t.track}`);
  console.log(JSON.stringify(plot, null, 2));
}
