# Bâbord / tribord — référentiel DataR0w

*Révisé le 18 septembre 2026 (barreur + overlay gîte).*

À l'aviron, bâbord et tribord sont **inversés** par rapport à la navigation classique.

## Pourquoi

- Marine : on nomme les bords **face à la proue**. Gauche = bâbord, droite = tribord.
- Aviron : le rameur regarde la **poupe**. Écran au cale-pied, face à l'athlète.

Conséquence : le **tribord aviron** est à **gauche** du rameur (et de l'écran),
le **bâbord aviron** à **droite**. Jamais le mapping marine PORT/STARBOARD dans l'app.

## Écrans rameur 2B / 3 / 4 (cale-pied)

Tare + live : **paysage**, haut du téléphone à **gauche** de l'écran
(`DeviceOrientation.landscapeLeft`, rotation UI 90°).

Les axes IMU sont ramenés à l'écran (`deviceToScreenVec`) :

| Côté écran (yeux rameur) | Libellé | Couleur jauge | Gîte |
|---|---|---|---|
| **Gauche** | **TRIBORD** | `#46C275` vert | `+` (gauche écran en bas) |
| **Droite** | **BÂBORD** | `#E05353` rouge | `−` |

Chip : `réf. rameur`.

Gauche écran en bas : le vecteur accéléro « ciel » penche vers la **droite** de l'UI
(`+screenX`) → gîte positive.

## Écran barreur (4+ / 8+)

Le barreur regarde vers la proue : **gauche écran = BÂBORD** rouge `#E05353`,
**droite = TRIBORD** vert `#46C275`. Chip `réf. barreur`.

Les rameurs du même bateau gardent la convention cale-pied (gauche = TRIBORD).
Deux profils, deux orientations d’écran, **un seul** signe stocké (réf. rameur).

Position : `coxPosition` `rear` (défaut) ou `front`. `seatIndex` = `null`.

## Alertes (|gîte| > 3° après tare)

Overlay haut d’écran (SafeArea), **sans décaler** le layout. Dégradé
semi-transparent (~80 % α) ~56 px : `#E05353` bâbord / `#46C275` tribords
→ transparent. Fade-in 150 ms, fade-out 300 ms. Vibration courte à l’apparition
seulement. Les deux côtés restent alertables.

Pas d'alerte unique ambre `#E8C547` pour la gîte. L'ambre reste pour le statut non-gîte.

## Coach 5 / 6

Même signe, mêmes couleurs. Pas de vocabulaire marine.
