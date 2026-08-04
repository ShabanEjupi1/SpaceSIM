#!/bin/sh
# Shpërndan ikonat e vizatuara te vendet ku i pret Android-i dhe Flutter Web-i.
# Ekzekutohet pas `vizato.mjs`, që i vizaton nga `store/ikona.html`.
#
#   sh store/vendos-ikonat.sh store/ikona-gen
set -eu

G="${1:?jep dosjen me PNG-të e vizatuara}"
R="$(cd "$(dirname "$0")/.." && pwd)"
A="$R/android/app/src/main/res"
W="$R/web"

# --- Android: ikona e nisjes ----------------------------------------------
cp "$G/ic_launcher-mdpi-48.png"     "$A/mipmap-mdpi/ic_launcher.png"
cp "$G/ic_launcher-hdpi-72.png"     "$A/mipmap-hdpi/ic_launcher.png"
cp "$G/ic_launcher-xhdpi-96.png"    "$A/mipmap-xhdpi/ic_launcher.png"
cp "$G/ic_launcher-xxhdpi-144.png"  "$A/mipmap-xxhdpi/ic_launcher.png"
cp "$G/ic_launcher-xxxhdpi-192.png" "$A/mipmap-xxxhdpi/ic_launcher.png"

# --- Android: ikona adaptive (API 26+) ------------------------------------
# Pa këtë, Android-i e vendos ikonën katrore brenda një rrethi të bardhë dhe
# aplikacioni duket si i pambaruar mes të tjerëve në ekranin kryesor.
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  density="${d%%:*}"; size="${d##*:}"
  mkdir -p "$A/drawable-$density"
  cp "$G/ic_launcher_foreground-$density-$size.png" \
     "$A/drawable-$density/ic_launcher_foreground.png"
done

# --- Flutter Web / PWA ----------------------------------------------------
mkdir -p "$W/icons"
cp "$G/pwa-icon-192.png"          "$W/icons/Icon-192.png"
cp "$G/pwa-icon-512.png"          "$W/icons/Icon-512.png"
cp "$G/pwa-icon-maskable-192.png" "$W/icons/Icon-maskable-192.png"
cp "$G/pwa-icon-maskable-512.png" "$W/icons/Icon-maskable-512.png"
cp "$G/pwa-favicon-32.png"        "$W/favicon.png"

echo "✓ ikonat u vendosën"
