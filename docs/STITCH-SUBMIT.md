# DataR0w — spec Stitch (coller tel quel)

Project: keep the existing board. Theme to use: **Marine Avionics Deck** only.
Do **not** use Nautical Avionics High-Vis. Do **not** iterate the 7 portrait screens on the top row.

Gold-master already on the board:
**Écran 3 — Rameur Live (Paysage 844×390 Instrument)**
Every new screen must look like that frame (tokens, type, density, no Material cards).

---

## Global rules

- App name: DataR0w. Language: French only.
- Phone bolted on a 1x footstretcher. Read at 80 cm in sun.
- Device for screens 3, 4, 5: **844 × 390 landscape**. If a frame is taller than wide, regenerate.
- Device for screens 1, 2, 6, 7: 390 × 844 portrait allowed, **same Deck theme**.
- Colors: background `#0B0E12`, numerals white tabular, labels `#9AA0A6`, hairlines `#2A2F36`, alert `#E8C547`.
- Forbidden: Material 3 cards, 24px rounded tiles, purple, cyan/teal High-Vis, blur, glass, bottom tab bar, hamburger, avatars, gears, watts, η, slip, YAML, Analyste, English UI, « inclinaison talon ».
- Heel label is always **GÎTE**.
- Speed caption always: `sol — pas eau`.

Generate **one screen per reply**, in this order: 4 → 5 → 1 → 2 → 6 → 7.
Do not regenerate écran 3 unless asked.

---

## Écran 4 — Rameur Alerte (do this first)

Duplicate Écran 3 paysage 844×390. Keep the three columns identical.
Add only a full-width bar at the top, height 36 px, fill `#E8C547`, text black centered:
`GÎTE — trop tribords`
No second alert, no toast, no portrait, no restyle.

---

## Écran 5 — Coach Live

New frame **844 × 390**, same Deck tokens as Écran 3 paysage.
- Left 60%: dark map, one thin GPS track, north up, no POI clutter.
- Right 40%: cadence `28 coups/min`, `4.2 m/s sol`, `GÎTE +1.4°`, chip `live`.
- Bottom: wide outline button `ANNOTER`.
No « envoyer au bateau », no charts, no High-Vis, no portrait.

---

## Écran 1 — Entrée / Profil

390 × 844, Deck theme, flat rows not elevated cards.
Title `DataR0w`.
Three rows: `Rameur` / `Coach` / `Barreur`.
Barreur greyed + caption `besoin d'un bateau barré`.
No Analyste. No High-Vis.

---

## Écran 2 — Pré-session

390 × 844, Deck theme.
Class `1x` selected. Field bassin (placeholder `Nantes-le-Joille` ok).
Sensors: `GPS` `IMU` on, BLE `— aucun`.
Button `Tare gîte (30 s)`. State `non faite`.
CTA `Démarrer la session`.
No cyan theme.

---

## Écran 6 — Coach Replay

390 × 844 or 844 × 390 if easier to keep Deck density.
Timeline + play/pause.
Two curves only: cadence and V sol. Annotation marks on the timeline.
One raw delta: `Δ cadence = +2`. No good/bad verdict. No 5-trace rainbow. Deck colors only.

---

## Écran 7 — Quai / fin de séance

390 × 844, Deck theme.
Four numbers only: durée, distance GPS, cadence moyenne, gîte RMS.
Sync chip `en attente réseau`.
Button `Partager au coach`.
Button `Retour accueil`.
No energy report, no PDF lab.

---

## Done when

Board contains:
- 1× écran 3 paysage (already exists — keep)
- 1× écran 4 paysage (3 + yellow bar)
- 1× écran 5 paysage coach
- écrans 1, 2, 6, 7 in Deck theme
- High-Vis theme unused
- top-row portraits unused
