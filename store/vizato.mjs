#!/usr/bin/env node
// Vizatuesi i grafikave të dyqanit: HTML → PNG me përmasa të sakta.
//
// Play-i kërkon ikonë 512×512 dhe grafikë 1024×500, dhe Android-i kërkon
// ikonën e nisjes në pesë dendësi. Në këtë makinë nuk ka asnjë vegël imazhi
// (as ImageMagick, as PIL), por ka një Chrome pa ekran — pra burimi është SVG
// i shkruar me dorë dhe Chrome-i është vizatuesi. Përparësia: e njëjta paletë,
// të njëjtat forma, çdo përmasë e mprehtë, pa asnjë varësi.
//
//   node vizato.mjs <url-e-chrome-debug> <dosja-dalëse> <spec.json>
//
// spec.json = [ { file, html, w, h, transparent? }, … ]  — `html` është shtegu
// brenda dosjes së këtij skedari, p.sh. "ikona.html?fg=1".
//
// 🚨 Chrome-i shërbehet me HTTP dhe jo me `file://`: ai rri në një kontejner
// tjetër nga ky skript, ndaj shtigjet e skedarëve këtu nuk ekzistojnë atje —
// një `file://` që s'gjendet nuk jep gabim, jep një faqe të bardhë bosh.

import { createServer } from 'node:http';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const DEBUG = process.argv[2] || 'http://127.0.0.1:9222';
const OUT = process.argv[3] || '.';
const SPEC = JSON.parse(readFileSync(process.argv[4], 'utf8'));
const ROOT = dirname(fileURLToPath(import.meta.url));

const sleep = ms => new Promise(r => setTimeout(r, ms));

const MIME = { '.html': 'text/html; charset=utf-8', '.svg': 'image/svg+xml',
               '.css': 'text/css; charset=utf-8', '.png': 'image/png' };

const srv = createServer((req, res) => {
  const path = normalize(join(ROOT, decodeURIComponent(req.url.split('?')[0])));
  if (!path.startsWith(ROOT)) return res.writeHead(403).end();
  try {
    const body = readFileSync(path);
    res.writeHead(200, { 'content-type': MIME[path.slice(path.lastIndexOf('.'))] || 'text/plain' });
    res.end(body);
  } catch { res.writeHead(404).end(); }
});
await new Promise(ok => srv.listen(0, '127.0.0.1', ok));
const BASE = `http://127.0.0.1:${srv.address().port}`;

const tab = await (await fetch(`${DEBUG}/json/new?about:blank`, { method: 'PUT' })).json();
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((ok, err) => { ws.onopen = ok; ws.onerror = err; });

let id = 0;
const waiting = new Map();
ws.onmessage = ev => {
  const m = JSON.parse(ev.data);
  const p = waiting.get(m.id);
  if (!p) return;
  waiting.delete(m.id);
  m.error ? p.err(new Error(m.error.message)) : p.ok(m.result);
};
const send = (method, params = {}) => {
  const n = ++id;
  ws.send(JSON.stringify({ id: n, method, params }));
  return new Promise((ok, err) => waiting.set(n, { ok, err }));
};

await send('Page.enable');

for (const t of SPEC) {
  await send('Emulation.setDeviceMetricsOverride', {
    width: t.w, height: t.h, deviceScaleFactor: 1, mobile: false,
  });
  // Sfond i tejdukshëm: e domosdoshme për pjesën e përparme të ikonës
  // adaptive — Android-i vendos vetë sfondin poshtë saj.
  await send('Emulation.setDefaultBackgroundColorOverride',
    t.transparent ? { color: { r: 0, g: 0, b: 0, a: 0 } } : {});

  await send('Page.navigate', { url: `${BASE}/${t.html}` });
  await sleep(700);
  await send('Page.bringToFront');
  const { data } = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(`${OUT}/${t.file}`, Buffer.from(data, 'base64'));
  console.log(`✓ ${t.file}  ${t.w}×${t.h}`);
}

await fetch(`${DEBUG}/json/close/${tab.id}`);
ws.close();
srv.close();
process.exitCode = 0;
