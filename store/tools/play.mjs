#!/usr/bin/env node
// Google Play Developer API — pa asnjë varësi.
//
//   node play.mjs <sherbimi.json> kontrollo <paketa>
//   node play.mjs <sherbimi.json> ngarko    <paketa> <skedari.aab> [gjurma] [shenimet.json]
//   node play.mjs <sherbimi.json> promovo   <paketa> <versionCode>  [gjurma] [shenimet.json]
//
// `kontrollo` është hapi i parë dhe i vetmi që duhet të besohet: ai thotë nëse
// llogaria e shërbimit e sheh vërtet aplikacionin. Tri gjëra ndryshme dështojnë
// këtu dhe ngatërrohen lehtë me njëra-tjetrën:
//   401  → çelësi/koha e sistemit
//   403  → llogaria s'është ftuar te Play Console, ose s'ka të drejtën «Lëshimet»
//   404  → paketa nuk ekziston ende te Play Console
// Vetëm e treta zgjidhet duke krijuar aplikacionin me dorë; API-ja NUK di ta
// krijojë një aplikacion të ri, dhe ngarkimin e parë e pranon vetëm pasi paketa
// të ekzistojë.
//
// Gjurmët: internal | alpha (testim i mbyllur) | beta (i hapur) | production

import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const [, , keyPath, cmd, pkg, aabPath, track = 'internal', notesPath] = process.argv;
if (!keyPath || !cmd || !pkg) {
  console.error('përdorimi: play.mjs <sherbimi.json> kontrollo|ngarko|promovo|listimi|gjendja ' +
    '<paketa> [aab|versionCode|listimi.json] [gjurma] [shenimet.json]');
  process.exit(2);
}

const key = JSON.parse(readFileSync(keyPath, 'utf8'));
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3';

const b64u = b => Buffer.from(b).toString('base64url');

async function token() {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const body = `${b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${b64u(JSON.stringify(claim))}`;
  const sig = createSign('RSA-SHA256').update(body).end().sign(key.private_key).toString('base64url');

  const r = await fetch(claim.aud, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${body}.${sig}`,
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`token ${r.status}: ${JSON.stringify(j)}`);
  return j.access_token;
}

const TOK = await token();

async function call(url, { method = 'GET', json, raw, type } = {}) {
  const r = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${TOK}`,
      ...(json ? { 'content-type': 'application/json' } : {}),
      ...(type ? { 'content-type': type } : {}),
    },
    body: json ? JSON.stringify(json) : raw,
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${url.replace(/\?.*/, '')} → ${r.status}\n${text}`);
  return text ? JSON.parse(text) : {};
}

// Emri i lëshimit dhe shënimet për çdo gjuhë, nga një skedar i vetëm te depoja
// (`store/shenimet.json`). Rrinë te git-i e jo te Console-i sepse janë pjesë e
// lëshimit njësoj si AAB-ja: një ngarkim pa to del te testuesit me emrin e
// zhveshur «3 (2.1.0)» dhe pa asnjë rresht se çfarë ndryshoi.
//
// 🚨 Play-i i pret shënimet deri në 500 shkronja për gjuhë dhe VETËM për gjuhët
// që ekzistojnë te listimi. Një gjuhë e panjohur e rrëzon `:commit`-in, jo
// ngarkimin — pra dështon në fund, pasi AAB-ja tashmë ka hipur.
//
// 🚨 `gjendja` (statusi i lëshimit) NUK është shije:
//   • sa kohë aplikacioni është ende «Draft» te Console-i — pra nuk ka dalë
//     kurrë te asnjë gjurmë e shqyrtuar — API-ja pranon VETËM `draft`. Një
//     `completed` bie me
//     «Only releases with status draft may be created on draft app» te `:commit`,
//     dhe bie PASI AAB-ja ka hipur, që duket sikur ngarkimi dështoi krejt.
//   • pasi aplikacioni të jetë publikuar një herë, `completed` e nxjerr
//     lëshimin te testuesit vetë; `draft` do të priste një klikim te Console-i.
function leshimi(versionCode) {
  const rel = { status: 'completed', versionCodes: [String(versionCode)] };
  if (!notesPath) return rel;
  const conf = JSON.parse(readFileSync(notesPath, 'utf8'));
  if (conf.gjendja) rel.status = conf.gjendja;
  if (conf.emri) {
    // 🚨 Emri i lëshimit: MAKS 50 SHKRONJA. Play-i e kthen këtë si 400 te
    // `:commit`, pra PASI AAB-ja ka hipur — dhe ndërtimi duket sikur dështoi
    // krejt. U kap më 2026-07-31 me një emër 62-shkronjësh te Tokërrgjiku,
    // ndërsa i shahut (46) kaloi: pra gabimi godet vetëm njërën depo dhe duket
    // si diçka tjetër. Matet KËTU, para çdo kërkese rrjeti.
    if (conf.emri.length > 50) {
      throw new Error(`emri i lëshimit: ${conf.emri.length} > 50 shkronja`);
    }
    rel.name = conf.emri;
  }
  const notes = Object.entries(conf.shenimet ?? {});
  if (notes.length) {
    rel.releaseNotes = notes.map(([language, text]) => ({ language, text }));
    for (const [lang, text] of notes) {
      if (text.length > 500) throw new Error(`shënimet ${lang}: ${text.length} > 500 shkronja`);
    }
  }
  return rel;
}

if (cmd === 'kontrollo') {
  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });
  const tracks = await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks`);
  console.log(`✓ hyrja funksionon për ${pkg}`);
  for (const t of tracks.tracks ?? []) {
    const rel = (t.releases ?? [])
      .map(r => `${r.status} ${(r.versionCodes ?? []).join(',') || '—'}`)
      .join(' | ') || 'bosh';
    console.log(`  ${t.track.padEnd(12)} ${rel}`);
  }
  await call(`${API}/applications/${pkg}/edits/${edit.id}`, { method: 'DELETE' });

} else if (cmd === 'ngarko') {
  if (!aabPath) throw new Error('mungon skedari .aab');
  const bytes = readFileSync(aabPath);

  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });
  console.log(`… ndryshimi ${edit.id}`);

  const bundle = await call(
    `${UPLOAD}/applications/${pkg}/edits/${edit.id}/bundles?uploadType=media`,
    { method: 'POST', raw: bytes, type: 'application/octet-stream' },
  );
  console.log(`… u ngarkua versionCode ${bundle.versionCode}`);

  await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks/${track}`, {
    method: 'PUT',
    json: { track, releases: [leshimi(bundle.versionCode)] },
  });
  console.log(`… u vendos te gjurma «${track}»`);

  await call(`${API}/applications/${pkg}/edits/${edit.id}:commit`, { method: 'POST' });
  console.log(`✓ u krye: ${pkg} ${bundle.versionCode} → ${track}`);

} else if (cmd === 'promovo') {
  // Ngjit një versionCode që EKZISTON te një gjurmë tjetër, pa e ringarkuar.
  //
  //   node play.mjs <çelësi.json> promovo <paketa> <versionCode> <gjurma>
  //
  // 🔑 Kjo është e vetmja mënyrë nga këtu për të nisur orën e testimit të mbyllur:
  // `internal` NUK numërohet për rregullin «12 testues × 14 ditë» dhe as nuk e nxjerr
  // aplikacionin nga gjendja «Draft», sepse është e vetmja gjurmë që Google-i s'e shqyrton.
  // `alpha` (= testim i mbyllur) po.
  //
  // 🚨 `:commit` dështon nëse ndonjë detyrë e Console-it mungon (listimi, klasifikimi i
  // përmbajtjes, Data safety, deklarimi i reklamave…). Ky dështim është INFORMATA që
  // duam: teksti i gabimit i emërton pikërisht ato që kanë mbetur.
  if (!aabPath) throw new Error('mungon versionCode');

  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });
  await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks/${track}`, {
    method: 'PUT',
    json: { track, releases: [leshimi(aabPath)] },
  });
  await call(`${API}/applications/${pkg}/edits/${edit.id}:commit`, { method: 'POST' });
  console.log(`✓ ${pkg} ${aabPath} → ${track}`);

} else if (cmd === 'listimi') {
  // Ngjit TË GJITHË listimin nga një skedar: kontaktet, tekstet për çdo gjuhë, dhe
  // figurat (ikona, grafika, pamjet). Kjo është pjesa e madhe e «Draft»-it që API-ja
  // DI ta bëjë — dhe ishte bosh te të dy aplikacionet (0/0 shkronja).
  //
  //   node play.mjs <çelësi.json> listimi <paketa> <listimi.json>
  //
  // Shtigjet e figurave lexohen relativisht ndaj vetë skedarit JSON.
  // ⛔ ÇKA NUK BËN DOT API-ja, dhe mbetet me dorë te Console-i: klasifikimi i
  //    përmbajtjes (IARC), «Siguria e të dhënave», publiku i synuar, deklarimi i
  //    reklamave, shtetet, dhe çmimi. Pa ato aplikacioni rri «Draft» edhe me listim
  //    të plotë — ndaj mos e lexo suksesin këtu si «u publikua».
  if (!aabPath) throw new Error('mungon listimi.json');

  const { dirname, resolve } = await import('node:path');
  const conf = JSON.parse(readFileSync(aabPath, 'utf8'));
  const base = dirname(resolve(aabPath));

  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });

  // 🔑 Tekstet SHKOJNË TË PARAT. `details.defaultLanguage` refuzohet nëse listimi i asaj
  // gjuhe nuk ekziston ende, dhe të dyja janë brenda të njëjtit `edit` — pra rendi këtu,
  // jo dy ekzekutime, është ajo që e bën shqipen gjuhë të parazgjedhur.
  for (const [lang, l] of Object.entries(conf.listings ?? {})) {
    await call(`${API}/applications/${pkg}/edits/${edit.id}/listings/${lang}`, {
      method: 'PUT',
      json: {
        language: lang,
        title: l.title,
        shortDescription: l.shortDescription,
        fullDescription: l.fullDescription,
        ...(l.video ? { video: l.video } : {}),
      },
    });
    console.log(`… teksti ${lang}: «${l.title}» (${l.shortDescription.length}/${l.fullDescription.length})`);
  }

  for (const [lang, sets] of Object.entries(conf.images ?? {})) {
    for (const [kind, files] of Object.entries(sets)) {
      const list = Array.isArray(files) ? files : [files];
      // Fshi çka është aty, ndryshe ngarkimet grumbullohen: `phoneScreenshots` mban
      // deri në 8 dhe një ekzekutim i dytë do t'i dyfishonte pamjet.
      await call(`${API}/applications/${pkg}/edits/${edit.id}/listings/${lang}/${kind}`,
                 { method: 'DELETE' });
      for (const f of list) {
        await call(
          `${UPLOAD}/applications/${pkg}/edits/${edit.id}/listings/${lang}/${kind}?uploadType=media`,
          { method: 'POST', raw: readFileSync(resolve(base, f)), type: 'image/png' },
        );
      }
      console.log(`… figurat ${lang}/${kind}: ${list.length}`);
    }
  }

  if (conf.details) {
    await call(`${API}/applications/${pkg}/edits/${edit.id}/details`, {
      method: 'PUT', json: conf.details,
    });
    console.log(`… detajet: ${conf.details.contactEmail ?? '—'} · ${conf.details.defaultLanguage ?? '—'}`);
  }

  await call(`${API}/applications/${pkg}/edits/${edit.id}:commit`, { method: 'POST' });
  console.log(`✓ listimi u ngjit për ${pkg}`);

} else if (cmd === 'gjendja') {
  // Çka di API-ja për gjendjen e listimit. NUK ekziston asnjë fushë «draft/published»
  // te Play Developer API — gjendja e aplikacionit rron vetëm te Console-i. Prandaj kjo
  // tregon atë që MUND të lexohet (kontaktet, gjuhët, listimet, gjurmët) dhe pjesën
  // tjetër e nxjerr nga mungesa: gjurmë të shqyrtueshme bosh = asgjë s'ka dalë kurrë.
  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });

  const details = await call(`${API}/applications/${pkg}/edits/${edit.id}/details`);
  console.log(`kontakti   ${details.contactEmail ?? '—'} · ${details.contactWebsite ?? '—'}`);
  console.log(`gjuha      ${details.defaultLanguage ?? '—'}`);

  const listings = await call(`${API}/applications/${pkg}/edits/${edit.id}/listings`);
  for (const l of listings.listings ?? [])
    console.log(`listimi    ${l.language}: «${l.title}» (${(l.shortDescription ?? '').length}/${(l.fullDescription ?? '').length} shkronja)`);
  if (!(listings.listings ?? []).length) console.log('listimi    ASNJË — aplikacioni s\'del dot nga «Draft» pa të');

  // 🚨 Figurat numërohen veç: tekstet mund të jenë ngjitur prej javësh dhe
  // «Set up your store listing» të rrijë prapë e kuqe sepse mungon ikona ose
  // pamjet — dhe kjo nuk duket askund te rreshtat më sipër. Ndodhi te eSIM-i
  // më 04-08-2026. Play-i kërkon ikonë, grafikë dhe ≥2 pamje telefoni.
  for (const l of listings.listings ?? []) {
    const numri = async (lloji) => ((await call(
      `${API}/applications/${pkg}/edits/${edit.id}/listings/${l.language}/${lloji}`)
    ).images ?? []).length;
    const [ikona, grafika, pamjet] =
      await Promise.all(['icon', 'featureGraphic', 'phoneScreenshots'].map(numri));
    const mungon = [!ikona && 'ikona', !grafika && 'grafika', pamjet < 2 && 'pamjet (<2)']
      .filter(Boolean).join(', ');
    console.log(`figurat    ${l.language}: ikona ${ikona} · grafika ${grafika} · pamje ${pamjet}` +
      (mungon ? `  ⛔ mungon: ${mungon}` : '  ✅'));
  }

  const tracks = await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks`);
  for (const t of tracks.tracks ?? []) {
    const rel = (t.releases ?? []).map(r => `${r.status} ${(r.versionCodes ?? []).join(',') || '—'}`).join(' | ') || 'bosh';
    console.log(`gjurma     ${t.track.padEnd(11)} ${rel}`);
  }

  await call(`${API}/applications/${pkg}/edits/${edit.id}`, { method: 'DELETE' });

} else if (cmd === 'zbraze') {
  // Zbraz një gjurmë: `zbraze <paketa> <gjurma>`.
  //
  // 🚨 Kjo ekziston për një gjendje të vetme, që te Console-i duket si gabim
  // i pashpjegueshëm: një lëshim i krijuar me dorë PA asnjë AAB. «Review
  // release» atëherë tregon dy gabime njëherësh —
  //   «This release does not add or remove any app bundles» (shkaku), dhe
  //   «doesn't allow any existing users to upgrade» (pasoja) —
  // dhe Console-i NUK jep asnjë buton «fshije këtë lëshim». E vetmja rrugë
  // është t'i dërgosh gjurmës një listë lëshimesh BOSH, që bëhet vetëm nga
  // API-ja. Pas kësaj gjurma kthehet e pastër dhe gabimet zhduken.
  const track = process.argv[5];
  if (!track) { console.error('jep gjurmën: zbraze <paketa> <gjurma>'); process.exit(2); }

  const edit = await call(`${API}/applications/${pkg}/edits`, { method: 'POST', json: {} });
  const para = await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks/${track}`);
  console.log(`para: ${(para.releases ?? []).map(r =>
    `${r.status} ${(r.versionCodes ?? []).join(',') || '—'}`).join(' | ') || 'bosh'}`);

  await call(`${API}/applications/${pkg}/edits/${edit.id}/tracks/${track}`,
    { method: 'PUT', json: { track, releases: [] } });
  await call(`${API}/applications/${pkg}/edits/${edit.id}:commit`, { method: 'POST' });
  console.log(`✓ gjurma ${track} u zbraz për ${pkg}`);

} else {
  console.error(`urdhër i panjohur: ${cmd}`);
  process.exit(2);
}
