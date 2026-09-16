# Prompt Stitch — correction DA (paysage instrument)

*16 septembre 2026 · backup avant collage dans Stitch.  
Référence visuelle validée : maquette cockpit 3 colonnes (cadence / gîte / statut).  
Ne pas réutiliser le pack portrait Material généré sur le projet 1264451048753434333.*

## Mode d'emploi Stitch

1. **Nouveau projet** (ne pas remixer les écrans portrait).
2. Device : **Mobile Landscape** — canvas **844 × 390**. Si l'UI n'offre que Portrait, abandonner et coller quand même le bloc « DEVICE » en tête.
3. Coller **un écran à la fois**. Commencer par écran 3 (Rameur live).
4. Joindre la capture de référence (téléphone paysage, fond #0B0E12, 3 colonnes) si Stitch accepte une image.
5. Si le rendu sort en portrait : arrêter. Ne pas empiler 7 prompts.

Titre à éviter dans l'UI : `INCLINAISON TALON`. Libellé correct : **GÎTE**.

---

## Bloc à coller — écran 3 Rameur live (correction DA)

```
STOP. Discard any previous portrait fitness / Material / card layout for this app.

DEVICE (mandatory):
- Smartphone LANDSCAPE only. Canvas 844×390 px.
- Not portrait. Not tablet. Not desktop. Not a tall scroll.
- If the frame is taller than it is wide, the output is invalid — regenerate.

PRODUCT: DataR0w. Phone bolted to the footstretcher of a 1x rowing shell.
Read at 80 cm in full sun. French UI only.

ART DIRECTION — marine cockpit instrument, locked:
- Background exactly #0B0E12. Flat. No cards, no elevation, no blur, no glass.
- No Material 3, no rounded 24px tiles, no purple, no teal, no gradients,
  no bottom navigation bar, no hamburger, no avatars, no settings gear.
- Type: huge white tabular numerals. Labels 11px #9AA0A6. Hairline dividers #2A2F36.
- One accent later (alert yellow #E8C547). Not on this calm frame.

LAYOUT — three columns, one row, no scroll:
LEFT ~42%
  28
  coups/min
  4.2
  m/s sol — pas eau
  1.24 km
CENTER ~38%  title: GÎTE  (never « inclinaison talon »)
  aircraft-style heel gauge, flat line art
  horizontal water reference, ±3° ticks, needle at +1.4°
  big readout +1.4°  tribords
RIGHT ~20%
  ● GPS   ● IMU
  4G  + signal bars
  62%  + battery outline
  STOP  rectangular outline button

FORBIDDEN: watts, charts, Plotly, slip, η, YAML, coach notes, English copy.
```

---

## Variante écran 4 — même frame + alerte

```
Same 844×390 landscape instrument as the previous screen. Do not change columns.
Add ONE full-width yellow (#E8C547) strip at the very top, 36px tall:
GÎTE — trop tribords
Black text on the strip. No second alert. No toast. No icons pack.
```

---

## Variante écran 5 — Coach live (même DA)

```
Same device 844×390, same colors #0B0E12 / white / #9AA0A6. No Material cards.
LEFT 60%: dark map, single GPS track, north up, no POI clutter.
RIGHT 40%: cadence, V sol, gîte +1.4°, link chip «live».
BOTTOM: one wide outline button ANNOTER.
No «send to boat». French only.
```

---

## Écrans 1, 2, 6, 7

Même palette et même interdiction Material. Portrait 390×844 autorisé seulement
pour 1 (profils), 2 (pré-session + tare), 6 (replay), 7 (quai). Si Stitch force
le paysage partout, garder paysage aussi sur ces quatre-là plutôt que retomber
en DA fitness.
