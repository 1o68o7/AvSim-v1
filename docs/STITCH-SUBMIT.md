# DataR0w — spec Stitch (coller tel quel)

Project: keep the existing board. Theme: **Marine Avionics Deck** only.
Do **not** use Nautical Avionics High-Vis. Do **not** iterate the top-row portraits.

Gold-master: **Écran 3 — Rameur Live (Paysage 844×390)** if it is Deck + no overlaps.
Otherwise regenerate 3 with the rules below.

---

## Global rules

- App: DataR0w. French only.
- Screens 3, 4, 5: artboard **844 × 390**. Taller-than-wide = invalid.
- Screens 1, 2A, 2B, 6, 7: 390 × 844 OK, same Deck tokens.
- Colors: `#0B0E12` / white / `#9AA0A6` / hairline `#2A2F36` / alert `#E8C547`.
- Forbidden: cyan High-Vis, REC, avatar, Material cards, watts, slip, Analyste, « inclinaison talon », « MODE PAYSAGE » in CTAs.
- Speed caption: `sol — pas eau`.
- Heel title: **GÎTE**.

### Bâbord / tribord (rowing, not marine)

Rowers face the stern. Labels follow the **rower's eyes**, opposite of a skipper facing the bow.

On every heel gauge and tare axis:
- **Left side of screen = BÂBORD**
- **Right side of screen = TRIBORD**
- Positive gîte / alert `trop tribords` = toward the **right** of the screen.

Do not draw a bow-up boat diagram that would flip this. Coach figures use the same sign. Caption allowed: `réf. rameur`.

---

## Écran 2A — Pré-session (paramétrage seul)

390×844. Class chips (1x on), bassin, sensors GPS / IMU / BLE `— aucun`.
One button: `Continuer — tare gîte`.
No gauge, no 30 s, no Démarrer.

## Écran 2B — Tare gîte (immobile)

390×844. No class, no bassin, no sensor list.
Title `Tare gîte`. Line: `Bateau à quai, coque calée. Ne pas bouger.`
Axis: left BÂBORD — 0.0° — right TRIBORD. Caption `réf. rameur`.
Yellow: `Tare gîte (30 s)`. Status `non faite`.
Bottom disabled: `Démarrer la session` until `OK ±0,2°`.

## Écran 3 — Rameur live 844×390

Three columns. Left: 28 / 4.2 / 1.24. Center: GÎTE, left BÂBORD, right TRIBORD, +1.4° tribords. Right: GPS IMU 4G 62% STOP.
No header, no avatar, no 1:59 overlapping speed.

## Écran 4 — Alerte

Duplicate 3. Top bar `#E8C547`: `GÎTE — trop tribords` (right-side heel).

## Écran 5 — Coach live 844×390

Map 60% + cadence / V sol / `GÎTE +1.4° tribords` + chip `réf. rameur` + `ANNOTER`.

## Écran 1 — Profils

Rameur / Coach / Barreur grisé `besoin d'un bateau barré`.

## Écran 6 — Replay

Two curves. Raw `Δ` only.

## Écran 7 — Quai

Four numbers. Sync. Partager. Retour.

Order: 2A → 2B → 3 → 4 → 5 → 1 → 6 → 7.
