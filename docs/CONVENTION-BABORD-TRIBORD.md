# Bâbord / tribord — référentiel DataR0w

*Figé le 16 septembre 2026.*

À l'aviron, bâbord et tribord sont **inversés** par rapport à la navigation classique.

## Pourquoi

- Marine : on nomme les bords **face à la proue** (sens de la marche). Gauche = bâbord, droite = tribord.
- Aviron : le rameur regarde la **poupe**. Les bords se nomment **face rameur**.

Conséquence dans le sens de la marche : le bâbord aviron est à **droite** du bateau, le tribord aviron à **gauche**. On n'utilise jamais le mapping marine dans l'app club.

## Écran rameur (téléphone au cale-pied, face au rameur)

Le rameur lit l'écran comme il voit le bateau.

| Côté écran (yeux rameur) | Libellé |
|---|---|
| **Gauche** | **BÂBORD** |
| **Droite** | **TRIBORD** |

Gîte `+` vers tribord = aiguille / valeur vers la **droite** de l'écran.
Alerte `GÎTE — trop tribords` = dépassement vers la droite écran.

Ne pas écrire « gauche bateau / droite bateau ». Ne pas dessiner une proue en haut de la jauge qui réinverserait le mapping.

## Écran tare (2B)

Même axe : gauche `BÂBORD`, droite `TRIBORD`, `0.0°` au centre. Une ligne de légende : `référentiel rameur`.

## Écran coach

La carte GPS est nord en haut (géographique). La **gîte chiffrée** reste dans le référentiel rameur (`+1.4° tribords` = même signe que sur l'écran bateau). Pas de second signe « marine ».

Chip discret autorisé : `réf. rameur`.
