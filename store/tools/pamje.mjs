#!/usr/bin/env node
// Pamjet e ekranit për Play Console, të marra nga aplikacioni i VËRTETË.
//
// Play-i kërkon pamje ekrani që tregojnë vërtet aplikacionin. Këtu nuk vizatohet
// asgjë me dorë: hapet ndërtimi i web-it (i njëjti kod Flutter si telefoni) në
// një Chrome pa ekran, i emuluar si telefon 360×640 @3x = 1080×1920 (9:16, saktë
// sa kërkon Play), klikohet nëpër lojë dhe fotografohet.
//
// Nuk ka asnjë varësi npm: CDP-ja flitet mbi `WebSocket`-in e vetë Node-it (22+).
//
//   node pamje.mjs <url-e-chrome-debug> <dosja-dalëse> [url-i-aplikacionit]
//
// Chrome-i pritet të jetë ndezur veçmas, p.sh.:
//   docker run -d --network host zenika/alpine-chrome \
//     --no-sandbox --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0

import { readFileSync, writeFileSync } from 'node:fs';

const DEBUG = process.argv[2] || 'http://127.0.0.1:9222';
const OUT = process.argv[3] || '.';
const APP = process.argv[4] || 'https://esim.spacecode.tech/';

const W = 360, H = 640, SCALE = 3;   // → 1080×1920

const sleep = ms => new Promise(r => setTimeout(r, ms));

// --- një klient CDP i vogël -------------------------------------------------
class Cdp {
  constructor(ws) { this.ws = ws; this.id = 0; this.waiting = new Map(); }

  static async open(wsUrl) {
    const ws = new WebSocket(wsUrl);
    await new Promise((ok, err) => { ws.onopen = ok; ws.onerror = err; });
    const cdp = new Cdp(ws);
    ws.onmessage = ev => {
      const msg = JSON.parse(ev.data);
      const p = cdp.waiting.get(msg.id);
      if (!p) return;                       // ngjarje — nuk na duhen
      cdp.waiting.delete(msg.id);
      msg.error ? p.err(new Error(msg.error.message)) : p.ok(msg.result);
    };
    return cdp;
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((ok, err) => this.waiting.set(id, { ok, err }));
  }

  // Një prekje e vërtetë: Flutter-i vizaton në canvas, pra asnjë selektor DOM
  // nuk e gjen dot butonin — pozicioni është e vetmja rrugë.
  async tap(x, y) {
    for (const type of ['mousePressed', 'mouseReleased']) {
      await this.send('Input.dispatchMouseEvent', {
        type, x, y, button: 'left', clickCount: 1, buttons: type === 'mousePressed' ? 1 : 0,
      });
      await sleep(60);
    }
    await sleep(900);
  }

  async shot(name) {
    // Pa këtë, Chrome-i pa ekran fotografon vetëm skedën e përparme: nëse ka
    // mbetur një skedë nga një ekzekutim i mëparshëm, thirrja dështon me
    // «Unable to capture screenshot» dhe asgjë tjetër nuk e tregon pse.
    await this.send('Page.bringToFront');
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    const file = `${OUT}/${name}.png`;
    writeFileSync(file, Buffer.from(data, 'base64'));
    console.log(`✓ ${file}`);
  }
}

// --- skenari ---------------------------------------------------------------
const ver = await (await fetch(`${DEBUG}/json/version`)).json();
console.log(ver['User-Agent']);

// /json/new kërkon PUT që nga Chrome 111.
const tab = await (await fetch(`${DEBUG}/json/new?about:blank`, { method: 'PUT' })).json();
const cdp = await Cdp.open(tab.webSocketDebuggerUrl);

await cdp.send('Page.enable');
await cdp.send('Emulation.setDeviceMetricsOverride', {
  width: W, height: H, deviceScaleFactor: SCALE, mobile: true,
});
await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });

// Chrome-i pa ekran nis gjithmonë në modë të ndritshme. Faqja e ka të errëtën
// si parazgjedhje dhe të ndritshmen si përjashtim (`prefers-color-scheme: light`
// te style.css), ndaj pa këtë rresht pamjet e dyqanit do të tregonin variantin
// që shumica nuk e sheh.
if (process.env.DARK) {
  await cdp.send('Emulation.setEmulatedMedia', {
    features: [{ name: 'prefers-color-scheme', value: 'dark' }],
  });
}

await cdp.send('Page.navigate', { url: APP });
await sleep(12000);                     // Flutter web: bootstrap + canvaskit

// Hapat vijnë nga një skedar dhe jo nga një ndryshore mjedisi: JSON-i me thonjëza
// nuk mbijeton dot dy nivele citimi (ssh → sh → docker).
const steps = process.env.STEPS_FILE
  ? JSON.parse(readFileSync(process.env.STEPS_FILE, 'utf8'))
  : [];
await cdp.send('Runtime.enable');

for (const s of steps) {
  // 🔑 `js` + `nav`: ky aplikacion nuk është lojë — ekranet interesante
  // («Të miat», kodi QR) janë BOSH derisa përdoruesi të ketë ruajtur një eSIM,
  // dhe shkrimi i tij kërkon të shtypësh brenda një canvas-i. Më e sigurt është
  // të mbillet vetë ruajtja: `shared_preferences_web` shkruan te
  // `localStorage['flutter.<çelësi>']` me vlerën `json.encode(<vargu>)`, pra një
  // varg JSON brenda një vargu JSON. Pastaj faqja ringarkohet.
  if (s.js) await cdp.send('Runtime.evaluate', { expression: s.js, awaitPromise: true });
  if (s.nav) { await cdp.send('Page.navigate', { url: s.nav === true ? APP : s.nav }); await sleep(9000); }
  if (s.tap) await cdp.tap(s.tap[0], s.tap[1]);
  if (s.wait) await sleep(s.wait);
  if (s.shot) await cdp.shot(s.shot);
}
if (!steps.length) await cdp.shot('00-fillimi');

// Skeda mbyllet gjithmonë: e lënë hapur, ekzekutimi i radhës nuk fotografon dot.
await fetch(`${DEBUG}/json/close/${tab.id}`);
cdp.ws.close();
process.exitCode = 0;                   // process.exit() pret stdout-in e tubuar
