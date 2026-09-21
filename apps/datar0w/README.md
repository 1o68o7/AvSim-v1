# DataR0w (`apps/datar0w`)

Companion téléphone : GPS / IMU d’un hub (cale-pied ou bateau). **Pas une mesure AvSim.**

Vérité produit : `docs/ETAT-DATAROW.md`. Sync club : `docs/CADRAGE-SUPABASE.md`.

Un smartphone = **un hub / une place**. Multi-sièges = plusieurs tél. + `DATAROW_API_BASE` (plus tard). Pas de 8 IMU simulés.

## Lots

| Lot | Contenu |
|---|---|
| B–E (télémétrie) | Logger 1 Hz après Démarrer, tare IMU, STOP, quai, replay, gîte lissée. |
| P0/P1 | Wakelock, FGS « DataR0w — séance », mag/baro/`estim. tel`. |
| G (API hub) | FastAPI `/datarow/*` + client si `DATAROW_API_BASE` (sinon fichier local). HTTP fail ≠ stop logger. |
| Coach | Join code / dernière séance / séance live API. Écran 5 OSM + notes. Replay import jsonl. |
| Classes | 1x, 2x, 2-, 4x, 4-, 4+, 8+. Rôle barreur 4+/8+. |
| I1–I8 / C1–C6 / D1–D5 | **Codés** : identité, parc ops, import cabane, spinoscope. Mapping : `docs/stitch-mvp/GEL.md`. |
| B (auth) | `/auth` + deep link. Magic link seulement si `SUPABASE_URL` + `SUPABASE_ANON_KEY`. Sinon local, pas de crash. Outbox Dart : pas sur main (branche #50). |
| E / L | `/calendar` `/calendar/:id` `/waters` — JSON curaté, **pas** de scrape FFA. |
| I live | Presets + mini-carte sur `/live` (Deck conservé). |
| R / J | Chip FC, `/devices` `/physio` `/consent`. Scan GATT 0x180D. |
| G mock | `club.licenceCountApprox` — estimation club, pas FFA. |
| Add-ons | Modes entraînement / compétition, patch UI (mock), sync quai mock, `uby-cazaubon`. **Sur main.** |

Routes : `/auth` `/calendar` `/calendar/:id` `/waters` `/consent` `/devices` `/physio`. Pas de route neuve add-on.

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

Auth club (optionnelle) : `--dart-define-from-file=dart_defines.json` (voir Run / APK).
Sans ces clés, `/auth` affiche le mode local — **pas de crash**.

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
cp dart_defines.example.json dart_defines.json
# éditer dart_defines.json : URL projet + clé anon public (eyJ…), JAMAIS service_role / sb_secret

flutter pub get
flutter run --release --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
# APK : build/app/outputs/flutter-apk/app-release.apk
```

`dart_defines.json` est **local** (gitignore). Ne pas committer. Sans fichier / clés vides : mode local, pas de crash.

SDK : `sdk.dir` dans `android/local.properties` (machine, **non committé**).  
`compileSdk = 37` (permission_handler_android).  
NDK **30.0.16248370** via Android Studio → SDK Tools (GUI).

Pas de cible `windows/` desktop.

## Hors contrat

Watts, η, slip, RTK, 10 Hz, Analyste, micro/caméra, High-Vis cyan, moteur AvSim, couloirs FISA sans GeoJSON, scrape FFA, paiement.
Patch firmware et LSTM : parked. Identité / parc / import / calendrier / auth route : **codés**.
