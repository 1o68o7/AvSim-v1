# DataR0w — patch Stitch manques profils

*16 septembre 2026. Coller tel quel dans le projet existant.*

## État

Garder :
- Écran 2A Configuration séance (classe / bassin / capteurs + `Continuer — tare gîte`)
- Écran 2B **portrait** Tare gîte (390×844) : BÂBORD à gauche, TRIBORD à droite, 0.0°, bouton jaune 30 s, statut `non faite`, Démarrer désactivé

Jeter / ne plus itérer :
- 2B paysage « labo » (tangage, lacet, 18 s + OK simultanés)
- Thème **Nautical Avionics High-Vis** (cyan). DESIGN.md = Marine Avionics Deck seulement
- Rang portrait High-Vis d'origine

---

## Règles communes

Theme: Marine Avionics Deck. `#0B0E12` / blanc / `#9AA0A6` / `#2A2F36` / alerte `#E8C547`.
French. No cyan, no REC, no avatar, no tab bar CONFIG/REPLAY/DEBRIEF, no RTK, no 10 Hz, no watts.
Bâbord = gauche écran, tribord = droite écran (réf. rameur, pas marine).
Generate **one screen per reply**, order below.

---

## 1 — Alléger Écran 1 (profils seulement)

390×844. Title `DataR0w`.
Three rows only: `Rameur` / `Coach` / `Barreur`.
Barreur locked + `besoin d'un bateau barré`.
Delete: SYS READY, 4G RTK, IMU alignée, orientation paysage, V1.0-MVP, bottom tabs, profile avatar.

---

## 2 — Nettoyer 2A (déjà presque bon)

Keep layout. Replace sensor lines with:
`GPS` · `IMU` · `BLE — aucun`
Remove `FIX RTK (0.4M)`, `10 Hz`, `100 Hz`.
Keep CTA `Continuer — tare gîte`.

---

## 3 — Écran 3 Rameur live (MANQUE — prioritaire)

Artboard **exactly 844×390**. If taller than wide, invalid.
No header, no avatar, no empty portrait padding.
Three columns, no scroll:
- Left: `28` coups/min · `4.2` m/s `sol — pas eau` · `1.24` km
- Center: title `GÎTE` · left `BÂBORD` · right `TRIBORD` · `+1.4° tribords`
- Right: GPS · IMU · 4G · 62% · `STOP`
No 1:59 overlapping speed. No « INSTRUMENTS PAYSAGE » title.

---

## 4 — Écran 4 Alerte (MANQUE)

Duplicate écran 3 844×390. Do not restyle.
Add top bar 36px `#E8C547` black text: `GÎTE — trop tribords`
(right-side heel, réf. rameur). One alert only.

---

## 5 — Écran 5 Coach live (MANQUE profil coach)

844×390 Deck.
Left 60%: dark map, one GPS track, north up.
Right: cadence, V sol, `GÎTE +1.4° tribords`, chip `live`, chip `réf. rameur`.
Bottom outline `ANNOTER`.
No send-to-boat. No High-Vis.

---

## 6 — Écran 6 Coach replay (MANQUE)

390×844 or 844×390 Deck.
Timeline + play. Two curves only: cadence, V sol.
Annotation marks. One raw `Δ cadence = +2`. No good/bad. No rainbow traces.

---

## 7 — Écran 7 Quai (MANQUE rameur + partage coach)

390×844 Deck.
Four numbers: durée, distance GPS, cadence moy., gîte RMS.
Chip `en attente réseau`.
`Partager au coach` · `Retour accueil`.
No energy PDF.

---

## Done when the board has

| # | Frame | Profil |
|---|---|---|
| 1 | 3 lignes profil, pas d'onglets | tous |
| 2A | config sans RTK | rameur |
| 2B | portrait tare seulement | rameur |
| 3 | 844×390 live | rameur |
| 4 | 3 + bandeau jaune | rameur |
| 5 | carte + annoter | coach |
| 6 | replay 2 courbes | coach |
| 7 | 4 chiffres + share | rameur / coach |

Barreur: cadenas écran 1 suffisant tant que classe = 1x.
