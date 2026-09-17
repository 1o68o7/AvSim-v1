# Bâbord / tribord — référentiel DataR0w

*Révisé le 17 septembre 2026 (inversion affichage rameur).*

À l'aviron, bâbord et tribord sont **inversés** par rapport à la navigation classique.

## Pourquoi

- Marine : on nomme les bords **face à la proue**. Gauche = bâbord, droite = tribord.
- Aviron : le rameur regarde la **poupe**. Écran au cale-pied, face à l'athlète.

Conséquence : le **tribord aviron** est à **gauche** du rameur (et de l'écran),
le **bâbord aviron** à **droite**. Jamais le mapping marine PORT/STARBOARD dans l'app.

## Écrans rameur 2B / 3 / 4 (cale-pied)

| Côté écran (yeux rameur) | Libellé | Couleur |
|---|---|---|
| **Gauche** | **TRIBORD** | `#46C275` vert |
| **Droite** | **BÂBORD** | `#E05353` rouge |

Gîte `+` = coque basse vers la **gauche** = tribords.  
Gîte `−` = coque basse vers la **droite** = bâbord.

Chip : `réf. rameur`.

## Alertes (|gîte| > 3° après tare)

- Trop **bâbord** (droite écran) : bandeau 36 px fond `#E05353`, texte blanc `GÎTE — trop bâbord`
- Trop **tribord** (gauche écran) : bandeau 36 px fond `#46C275`, texte sombre `GÎTE — trop tribords`

Pas d'alerte unique ambre `#E8C547` pour la gîte. L'ambre reste pour le statut non-gîte.

## Coach 5 / 6

Même signe, mêmes couleurs. Pas de vocabulaire marine.
