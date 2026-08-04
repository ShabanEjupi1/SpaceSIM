# SpaceSIM — pako eSIM për udhëtim

Flutter, një burim për **Android + web**. Live: **esim.spacecode.tech**.

## 🚨 Gjendja: PROVË, jo shitje

Nuk ka furnizues të vërtetë ende, ndaj aplikacioni punon me
`FurnizuesISimuluar`. Profilet që jep NUK janë të vërteta — LPA-ja e tyre
tregon te një server që s'ekziston, prandaj një telefon do t'i refuzonte.
Kjo është me qëllim: **një profil i rremë që *duket* i vërtetë është më i keq se
një gabim i qartë.** Shiriti i verdhë «PROVË» rri sipër derisa
`Furnizuesi.iVertete` të kthejë `true`, dhe një test e mbron atë kusht.

## 📣 Reklamat (nga 0.2.0)

Të gjitha rregullat te **`lib/app/ads.dart`**, një skedar i vetëm. Banderolë mbi
shiritin e lundrimit; interstitial vetëm **pas** mbylljes së kodit QR dhe jo më
shpesh se një në 4 minuta; pa reklamë me shpërblim dhe pa app-open.

🚨🚨 **Asnjë reklamë mbi ekranin e kodit QR.** Atë ekran e lexon një pajisje e
DYTË që po skanon (telefoni nuk e skanon dot ekranin e vet), ndaj çdo reklamë
atje bie brenda kuadratit që kamera po lexon dhe skanimi dështon pa e ditur
askush pse. Kjo mbrohet nga një test që lexon **burimin** e
`faqja_profilit.dart` — një test widget-i do të kapte vetëm banderolën, jo një
interstitial.

🚨 Reklamat sollën lejen `INTERNET` dhe (përmes bashkimit të manifesteve)
`AD_ID`. Prandaj u ndryshuan njëkohësisht: `store/listimi.json` (sq **dhe**
en-US), ky README, `web/privatesia.html` dhe
[`linux-install/PLAY-ESIM.md`](../linux-install/PLAY-ESIM.md). Një listim që
kundërshton «Sigurinë e të dhënave» është nga shkaqet më të shpeshta të
pezullimit.

Aplikacioni mbetet i plotë pa rrjet: katalogu, eSIM-et dhe QR-i janë vendëse.
Ndërtimi web (esim.spacecode.tech) nuk shfaq asnjë reklamë — `Ads.supported`
është `false` jashtë Android/iOS.

## 🔑 I gjithë furnizuesi rri pas një ndërfaqeje

`lib/furnizuesi/furnizuesi.dart` është i vetmi skedar që e di se ekziston një
furnizues. Kur të vijë çelësi (Airalo Partner, eSIM Go, Maya), shtohet një
zbatim i dytë dhe ndërrohet **një rresht te `main.dart`**. Asnjë ekran nuk preket.

## Ndërtimi

```bash
export PATH=$PATH:/mnt/data/flutter/bin        # vetëm në Ampere
flutter analyze && flutter test                 # analyze del jozero edhe për `info`
flutter build web --release --pwa-strategy=none
```
🚨 `--pwa-strategy=none`: me shërbëtorin e punës të Flutter-it, shfletuesi
shërben ndërtimin e vjetër edhe pas rsync-ut edhe pas pastrimit të Cloudflare-it.

## Vendosja

`/mnt/data/esim-web` ← dalja; kontejneri `esim` (nginx:alpine, 127.0.0.1:8225),
tuneli `ampere`, rregull ingresi **para** `*.spacecode.tech` — përndryshe e merr POS-i.
Compose + nginx: `linux-install/esim-web/`.

## Çfarë mbetet para se të shitet një pako e vetme

1. **Furnizuesi** — llogari partneri dhe çelës API. Pa të, s'ka katalog dhe s'ka profil.
2. **Pagesa** — PayPal-i ekziston; duhet lidhur, me faturë dhe politikë kthimi.
3. **Play** — Data safety, publiku i synuar, kontakt i vërtetë; blerjet reale i
   ndryshojnë të gjitha përgjigjet e sotme **për të dytën herë** (reklamat i
   ndryshuan një herë më 04-08-2026; shitja shton «Purchase history»).
4. **Pajtueshmëria** — kontrolli `*#06#` / EID shfaqet PARA çmimeve me qëllim:
   ankesa më e shpeshtë e këtij zhanri është një telefon i kyçur ose pa eSIM,
   dhe atëherë blerja ka ndodhur tashmë.
