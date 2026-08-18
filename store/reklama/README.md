# Reklama e shtypur për eSIM Space

Posterë për mure — shtypen dhe ngjiten. Kërkesë e Shabanit, 18-08-2026:
*«need advertising for my esim app so that I print its and add in walls for
people to see and register my app and buy my packages»*.

## Çfarë ka këtu

| Skedari | Çfarë është |
|---|---|
| `posteri.html` | burimi, A4 portret te 300 DPI (2480 × 3508 px) |
| `qr-play.png` | QR → faqja e Play-it (`tech.spacecode.esim`), korrigjim **H** |
| `qr-web.png` | QR → `esim.spacecode.tech` |
| `poster-esim-A4.png` | dalja për shtyp |

## Si rivizatohet

```bash
# 1. Kodet QR (vetëm nëse ndryshon adresa)
sudo docker run --rm -v "$PWD":/o alpine:3.20 sh -c \
  'apk add -q libqrencode-tools && qrencode -o /o/qr-play.png -s 12 -m 0 -l H \
   "https://play.google.com/store/apps/details?id=tech.spacecode.esim"'

# 2. Posteri
node ../vizato.mjs http://127.0.0.1:9222 . grafikat.json
```

## 🚨 Tri gjëra që nuk duhen ndryshuar pa i matur

1. **Korrigjimi i QR-së është `-l H`, jo `L`.** Një poster muri merr dritë të
   dobët, njolla dhe kënde të shtrembër; niveli H rikthen deri 30% të kodit të
   humbur. `L` jep një kod më të imët që duket më i pastër te ekrani dhe
   dështon te muri — pra defekti shfaqet vetëm pas shtypjes.
2. **QR-ja mbetet ≥ 52 mm.** Nën 40 mm një telefon i mesëm nuk e kap dot nga
   largësia ku njeriu ndalet për ta lexuar posterin.
3. **`deviceScaleFactor` mbetet 1.** Mbi 1, `captureScreenshot` i Chrome-it pa
   GPU kthen 360×640 pa asnjë gabim — shih [[pamjet-chrome-pa-gpu-shkalla]].
   Madhësia e vërtetë shkruhet te CSS-ja.

🕌 Asnjë qenie e gjallë te vizatimi — vetëm gjeometri dhe tipografi.
🔒 Firma është «SpaceCode»; mbiemri nuk del te asnjë material publik.
