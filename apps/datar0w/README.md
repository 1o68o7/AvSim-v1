# DataR0w (`apps/datar0w`)

Companion téléphone **1x** : GPS / IMU du cale-pied. **Pas une mesure AvSim.**
Aucune sortie n’est une vérité terrain du solveur.

Maquettes : `docs/stitch-mvp/GEL.md` (Deck). Ne pas porter les HTML « jeter ».

## Lots

| Lot | État |
|---|---|
| A | Scaffold, thème Deck, `go_router` 1 / 2A / 2B / 3 / 5 / 6 / 6r / 7 |
| B | Permissions + overlay GPS/roll brut + `sessions/{id}/samples.jsonl` |
| C–G | Tare 30 s, STOP 2×, replay, coach join, API — **pas encore** |

## Run (device réel, ciel ouvert)

```bash
cd apps/datar0w
flutter pub get
flutter run
```

- iOS : Xcode + signing ; accepter Localisation et Mouvements.
- Android : activer le GPS ; accepter Fine location puis, plus tard, background.
- Montage : téléphone **boulonné au cale-pied, paysage**, écran face au rameur.
  Gauche écran = **BÂBORD**, droite = **TRIBORD** (réf. rameur, yeux vers la poupe).
- Vitesse toujours légendée **sol — pas eau**. Cadence peut être `—` (nullable).
- Alerte gîte : bandeau `#E8C547` `GÎTE — trop tribords` si roll brut > +3° (tare lot C).
- Fichier séance : `Documents/sessions/{id}/samples.jsonl` (1 Hz). Overlay live = GPS + roll brut.

## Simulateur

Le simulateur iOS/Android n’a pas d’IMU/GPS fiables. Le lot B se juge sur **téléphone réel**.

## Hors contrat

Watts, η, slip, RTK, 10 Hz GNSS, Analyste, micro/caméra, moteur AvSim.
