#!/usr/bin/env node
// Pastro gjurmët: heq artefaktet e VJETRA që rrinë ende «aktive» te gjurmët e
// testimit, duke i zëvendësuar me versionCode-in e sotëm.
//
//   node pastro-gjurmet.mjs <çelësi.json> <paketa> <versionCode> <gjendja> <gjurma…>
//
// 🚨 PSE EKZISTON: Play-i i vlerëson rregullat (target API, leja `AD_ID`, Data
//    safety) mbi TË GJITHA artefaktet aktive — jo vetëm mbi atë të prodhimit.
//    Një ndërtim i vjetër i harruar te `internal` mjafton për të bllokuar një
//    lëshim krejt të ri:
//      • Mat! kishte versionCode 3 (targetSdk 35) te `internal` → «App must
//        target Android 16»; ndërsa 4, 5 dhe 6 janë të gjitha 36.
//      • Tokërrgjiku kishte versionCode 20 (2.0.0, PA AdMob, pra pa lejen
//        `AD_ID`) te `internal` → «A manifest file in one of your active
//        artifacts doesn't include the AD_ID permission».
//    Në të dyja rastet mesazhi tregon nga aplikacioni, jo nga gjurma, ndaj duket
//    sikur faji e ka lëshimi i ri. Nuk e ka.
//
// ⚠️ «gjendja» duhet `draft` sa kohë aplikacioni nuk është botuar ende
//    (Tokërrgjiku), dhe `completed` pasi është botuar (Mat!, Girih). E kundërta
//    bie te `:commit`.

import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const [keyPath, pkg, versionCode, gjendja, ...gjurmet] = process.argv.slice(2);
if (!keyPath || !pkg || !versionCode || !gjendja || !gjurmet.length) {
  console.error('përdorimi: pastro-gjurmet.mjs <çelësi.json> <paketa> <versionCode> <draft|completed> <gjurma…>');
  process.exit(2);
}

const key = JSON.parse(readFileSync(keyPath, 'utf8'));
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o))
  .toString('base64url');

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
  const sig = createSign('RSA-SHA256').update(`${head}.${body}`).end()
    .sign(key.private_key, 'base64url');
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

async function call(url, opts = {}) {
  const r = await fetch(url, {
    ...opts,
    headers: {
      authorization: `Bearer ${tok}`,
      ...(opts.json ? { 'content-type': 'application/json' } : {}),
    },
    body: opts.json ? JSON.stringify(opts.json) : undefined,
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${r.status} ${url}\n${t}`);
  return t ? JSON.parse(t) : {};
}

const edit = await call(`${API}/${pkg}/edits`, { method: 'POST', json: {} });

for (const gjurma of gjurmet) {
  const para = await call(`${API}/${pkg}/edits/${edit.id}/tracks/${gjurma}`);
  const kishte = (para.releases ?? [])
    .map((r) => `${r.status} ${(r.versionCodes ?? []).join(',') || '—'}`)
    .join(' | ') || 'bosh';

  const rel = { status: gjendja, versionCodes: [String(versionCode)] };
  // Një lëshim i shkallëzuar do të kërkonte `userFraction`; këtu gjithmonë 100%.
  await call(`${API}/${pkg}/edits/${edit.id}/tracks/${gjurma}`, {
    method: 'PUT',
    json: { track: gjurma, releases: [rel] },
  });
  console.log(`  ${gjurma.padEnd(10)} ${kishte}  →  ${gjendja} ${versionCode}`);
}

await call(`${API}/${pkg}/edits/${edit.id}:commit`, { method: 'POST' });
console.log(`✓ ${pkg}: gjurmët u pastruan`);
