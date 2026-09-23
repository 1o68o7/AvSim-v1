# Écarts Stitch → Flutter (lot visuel)

*23 sept 2026. Projet `1264451048753434333`. Mapping routes : [GEL.md](GEL.md).*

Objectif : coller les **assets utiles** des planches gelées dans les routes
existantes. Pas de nouvelle route labo. Pas de jargon (SYS_ID, RTK, 10 Hz,
NODE, CANAL). Pas de fausse courbe FC / SpO2 / readiness inventée.

## Lot 1 — intégré (cette PR)

| Planche | Route | Manque comblé |
|---|---|---|
| Accueil Rameur (I5) | `/home/rower` | Fiche athlète (côté, cat., poids, taille), carte session (poste, pelles, barreur), strip sièges étrave→poupe, CTA « Continuer vers la séance » + Voir mon club |
| Accueil Barreur (I5) | `/home/cox` | Affectation coque, poste avant/arrière, équipage lecture seule + chips BÂBORD/TRIBORD |
| Accueil Coach (I5) | `/home/coach` | Cartes Composer / Rejoindre, aperçu rameurs + parc |
| J1 Mes objets | `/devices` | Cartes objet (icône, sync, batterie), CTA scan Stitch, note patch, Oublier |
| J2/J3 Constantes | `/physio` | Chips 7/28/90 j, dernière séance réelle, pods GPS/SPM/gîte, historique → replay, CTA partage coach |
| Quai épuré | `/quai` | CTA primaire Partager au coach (comme planche épurée) |

## Volontairement non iso

| Élément Stitch | Pourquoi |
|---|---|
| NODE / SYS_REF / CANAL / COCKPIT_M1 | Interdit GEL |
| RTK, 10 Hz, watts, η, assiette 3D pitch | Hors contrat club |
| Score readiness chiffré + anneau | Pas assez de FC réel (ÉTAT §2.3) |
| Overlay FC/SPM/PACE sur `/physio` | Courbes = replay ; pas inventer |
| Montre / brassard hors GATT 0x180D | Produit = sangle + patch mock |
| 2B paysage labo, R2 live dense | Ignorés GEL |

## Hors lot (déjà codé / autre PR)

Headers Deck (`DATAR0W / TITRE`) — PR headers. Modes ENTRAÎNEMENT|COMPÉTITION,
patch mock, Importer patch — add-ons GEL sur main.
