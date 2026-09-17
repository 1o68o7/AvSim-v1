# DataR0w (`apps/datar0w`)

Companion téléphone **1x** : GPS / IMU du cale-pied. **Pas une mesure AvSim.**

## Lots B–E (cette branche)

| Lot | Contenu |
|---|---|
| B | Permissions (refus = message FR). Logger 1 Hz **après Démarrer**. `samples.jsonl` + `imu.jsonl` brut. Distance haversine si `acc_h < 25 m`. Trou GPS si fix perdu. `sol — pas eau`. Cadence `—`. |
| C | Tare 30 s : moyenne du **niveau IMU** (gravité accéléro), σ < 0,2°, `tareOffsetDeg` dans `meta.json`. Démarrer off sinon. Après tare, 0° = ce niveau. |
| D | STOP 2× / 3 s → `LiveHub.stop()` → quai. Bandeaux gîte **deux côtés**. |
| E | Quai 4 chiffres + Replay + Partager **jsonl+meta**. Replay carte, playhead, 2 courbes, pas d’interpolation. |

## Gîte — lissage

- Filtre complémentaire gyro + accéléro, τ ≈ 0,32 s. L’IMU brut **ne** pousse **pas** le gros chiffre.
- UI 12,5 Hz (80 ms), deadband ±0,15° à l’affichage.
- Brut dans `imu.jsonl` pendant la séance.

## BÂBORD / TRIBORD (réf. rameur)

Gauche écran = **TRIBORD** vert `#46C275`. Droite = **BÂBORD** rouge `#E05353`.  
Alerte trop tribords : bandeau **vert foncé** `#0F5C32`. Trop bâbord : `#E05353`.  
`+` = tribords (gauche écran en bas). IMU en axes écran (paysage, rotation 90°). Voir `docs/CONVENTION-BABORD-TRIBORD.md`.

## Run / APK (Android)

Chemin projet **sans espaces** recommandé (`C:\dev\AvSim-v1`).

```bash
cd apps/datar0w
flutter pub get
flutter run
flutter build apk --debug
```

APK : `apps/datar0w/build/app/outputs/flutter-apk/app-debug.apk`

SDK : `sdk.dir` dans `android/local.properties` (machine, **non commité**).  
`compileSdk = 37` (permission_handler_android).  
NDK **30.0.16248370** via Android Studio → SDK Tools (GUI). **Ne pas** lancer `sdkmanager` en CLI depuis Gradle (crash Windows).

Pas de cible `windows/` desktop.

## Hors contrat

Watts, η, slip, RTK, 10 Hz, Analyste, micro/caméra, High-Vis cyan, moteur AvSim.
