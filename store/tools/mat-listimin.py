#!/usr/bin/env python3
"""Mat gjatësitë e listimit PARA se të preket rrjeti.

🚨 Play-i i kthen këto si 400 te `:commit` — pra PASI gjithçka tjetër ka hipur,
dhe gabimi duket sikur ngjitja e listimit dështoi krejt. Kufijtë (matur në
SHKRONJA, jo bajt — prandaj `ë` numëron një):

    title             30
    shortDescription  80
    fullDescription   4000

    python3 store/tools/mat-listimin.py store/listimi.json
"""
import json
import sys

KUFIJTE = {'title': 30, 'shortDescription': 80, 'fullDescription': 4000}

rruga = sys.argv[1] if len(sys.argv) > 1 else 'store/listimi.json'
with open(rruga, encoding='utf-8') as f:
    listimi = json.load(f)

gabime = 0
for gjuha, l in listimi.get('listings', {}).items():
    for fusha, kufiri in KUFIJTE.items():
        n = len(l.get(fusha, ''))
        shenja = 'ok ' if n <= kufiri else 'MBI'
        if n > kufiri:
            gabime += 1
        print(f'{shenja} {gjuha:6} {fusha:16} {n:5}/{kufiri}')

detajet = listimi.get('details', {})
print(f'    kontakti  {detajet.get("contactEmail", "—")} · {detajet.get("contactWebsite", "—")}')
print(f'    gjuha     {detajet.get("defaultLanguage", "—")}')

if gabime:
    print(f'\n🚨 {gabime} fusha mbi kufi — Play-i do ta rrëzonte :commit-in.')
sys.exit(1 if gabime else 0)
