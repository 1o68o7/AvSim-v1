# DataR0w (`apps/datar0w`)

Companion téléphone : GPS / IMU d’un hub (cale-pied ou bateau). **Pas une mesure AvSim.**

Un smartphone = **un hub / une place**. Multi-sièges = plusieurs tél. + `DATAROW_API_BASE` (plus tard). Pas de 8 IMU simulés.

## Lots

| Lot | Contenu |
|---|---|
| B–E (télémétrie) | Logger 1 Hz après Démarrer, tare IMU, STOP, quai, replay, gîte lissée. |
| P0/P1 | Wakelock, FGS « DataR0w — séance », mag/baro/`estim. tel`. |
| G (API hub) | FastAPI `/datarow/*` + client si `DATAROW_API_BASE` (sinon fichier local). HTTP fail ≠ stop logger. |
| Coach | Join code / dernière séance / séance live API. Écran 5 OSM + notes. Replay import jsonl. |
| Classes | 1x, 2x, 2-, 4x, 4-, 4+, 8+. Rôle barreur 4+/8+. |
| I1–I8 / C1–C6 / D1–D5 | **Codés** : identité, parc ops, import cabane, spinoscope. Mapping Stitch : `docs/stitch-mvp/GEL.md`. |
| B (auth) | Magic link Supabase si `SUPABASE_URL` + `SUPABASE_ANON_KEY`. Sinon mode local, pas de crash. |
| E / L | Calendrier + plans d’eau (JSON curaté, pas de scrape FFA). Filtres loisir / rando / master. |
| I live / R / J | Presets live + mini-carte ; chip FC BLE ; `/devices` `/physio` `/consent`. |

## Un téléphone = un hub = une place

Le siège n’existe **que** dans la classe choisie (écran 2A : classe, puis siège).
`boatConfigProvider` porte `class` / `seats` / `cox` / `role` / `seatIndex` de 2A → 2B → live.
Au Démarrer, les mêmes champs sont écrits dans `meta.json` (persistants pour le replay).

Les autres places du bateau restent **en attente** en local. Avec `DATAROW_API_BASE`, le
barreur / coach peut **poll** `GET /datarow/live` (Lot G). Un seul tél. ne simule pas 8 IMU.

## API optionnelle

```
# dart-define ou env
DATAROW_API_BASE=http://192.168.x.x:8000
python -m avsim.api
```

Routes (sans OAuth) : `POST /datarow/sessions`, `.../tick`, `GET .../by-code/{code}`, `GET .../live`, `POST .../notes`, `GET .../export`.

## Gîte — lissage

- Filtre complémentaire gyro + accéléro, τ ≈ 0,32 s. L’IMU brut **ne** pousse **pas** le gros chiffre.
- UI 12,5 Hz (80 ms), deadband ±0,15° à l’affichage.
- Brut dans `imu.jsonl` pendant la séance.

## BÂBORD / TRIBORD (réf. rameur)

Gauche écran = **TRIBORD** vert `#46C275`. Droite = **BÂBORD** rouge `#E05353`.  
Alerte : overlay haut d’écran semi-transparent (bâbord `#E05353` / tribords `#46C275`).  
`+` = tribords (gauche écran en bas). IMU en axes écran (paysage, rotation 90°). Voir `docs/CONVENTION-BABORD-TRIBORD.md`.

Barreur : **gauche = BÂBORD**, droite = TRIBORD (`réf. barreur`). Cadence = « — » ou estim. tel.

Navigation : BARREUR + classe 4+/8+ + tare (Démarrer) → **`/cox`** (`CoxLiveScreen`), **pas** `/live`. Rameur → `/live`. STOP 2× → `/quai`. 2A/2B : « Retour profil » (sauf tare en cours).

**Pendant `/live`, `/cox`, `/coach` : pas de bouton Accueil.** Sortie = STOP 2× → quai. On ne quitte pas un enregistrement par accident.

## Baro

`sensors_plus` `barometerEventStream` seulement. **Pas** `environment_sensors` (jcenter / AGP 9). Sinon `p_hpa` / `alt_baro` = `null`.

## Run / APK (Android)

Chemin projet **sans espaces** recommandé (`C:\dev\AvSim-v1`).

```bash
cd apps/datar0w
flutter pub get
flutter run --dart-define=DATAROW_API_BASE=http://192.168.1.10:8000
flutter build apk --debug
```

APK : `apps/datar0w/build/app/outputs/flutter-apk/app-debug.apk`

SDK : `sdk.dir` dans `android/local.properties` (machine, **non committé**).  
`compileSdk = 37` (permission_handler_android).  
NDK **30.0.16248370** via Android Studio → SDK Tools (GUI).

Pas de cible `windows/` desktop.

## Hors contrat

Watts, η, slip, RTK, 10 Hz, Analyste, micro/caméra, High-Vis cyan, moteur AvSim, couloirs FISA sans GeoJSON.
Identité / parc / import : I1–I8, C, D **codés**. Hors contrat : Watts, η, scrape FFA, paiement.
