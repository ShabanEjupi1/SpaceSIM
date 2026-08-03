# SpaceSIM — pako eSIM për udhëtim

Flutter, një burim për **Android + web**. Live: **esim.spacecode.tech**.

## 🚨 Gjendja: PROVË, jo shitje

Nuk ka furnizues të vërtetë ende, ndaj aplikacioni punon me
`FurnizuesISimuluar`. Profilet që jep NUK janë të vërteta — LPA-ja e tyre
tregon te një server që s'ekziston, prandaj një telefon do t'i refuzonte.
Kjo është me qëllim: **një profil i rremë që *duket* i vërtetë është më i keq se
një gabim i qartë.** Shiriti i verdhë «PROVË» rri sipër derisa
`Furnizuesi.iVertete` të kthejë `true`, dhe një test e mbron atë kusht.

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
   ndryshojnë të gjitha përgjigjet e sotme.
4. **Pajtueshmëria** — kontrolli `*#06#` / EID shfaqet PARA çmimeve me qëllim:
   ankesa më e shpeshtë e këtij zhanri është një telefon i kyçur ose pa eSIM,
   dhe atëherë blerja ka ndodhur tashmë.
