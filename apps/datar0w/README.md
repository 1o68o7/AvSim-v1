# DataR0w (`apps/datar0w`)

Companion téléphone **1x** : GPS / IMU du cale-pied. **Pas une mesure AvSim.**
Aucune sortie n’est une vérité terrain du solveur.

Maquettes : `docs/stitch-mvp/GEL.md` (Deck). Ne pas porter les HTML « jeter ».

## Lots

| Lot | État |
|---|---|
| A | Scaffold, thème Deck, `go_router` 1 / 2A / 2B / 3 / 5 / 6 / 6r / 7 |
| B | Permissions + overlay GPS/roll brut + `sessions/{id}/samples.jsonl` |
| C | Tare 30 s, σ < 0,2°, offset `meta.json`, Démarrer off sinon, gîte = roll − offset |
| D | STOP 2× en 3 s → stop logger → quai. Alerte jaune si gîte > +3° tribords |
| E | Quai 4 chiffres + Replay + Partager jsonl. 6/6r : carte, curseur, 2 courbes, pas d’interp. GPS |
| F | Code 6 car. à Démarrer, join coach local, écran 5 carte + ANNOTER. HTTP si `DATAROW_API_BASE` |
| G | API FastAPI `/datarow` — **pas encore** (client seulement si base URL) |

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
- Alerte gîte : bandeau `#E8C547` si **gîte** (roll − offset) > +3° tribords.
- Tare 2B : 30 s, σ < 0,2°, sinon recommencer. Démarrer inactif tant que tare ≠ OK.
- Fichier séance créé à **Démarrer** : `Documents/sessions/{id}/meta.json` (`tare_offset`, `code`) + `samples.jsonl` 1 Hz.
- Coach : code 6 caractères, mode **local** (même téléphone). API tick uniquement si `DATAROW_API_BASE` est défini (`--dart-define` ou env).

## Simulateur

Le simulateur iOS/Android n’a pas d’IMU/GPS fiables. Le lot B se juge sur **téléphone réel**.

## Hors contrat

Watts, η, slip, RTK, 10 Hz GNSS, Analyste, micro/caméra, moteur AvSim.
