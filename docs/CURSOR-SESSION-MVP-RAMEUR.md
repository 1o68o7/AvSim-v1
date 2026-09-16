# DataR0w — cadrage session Cursor Agent

*16 septembre 2026. Document unique à coller / à ouvrir en début de session Cursor.*

Repo : `https://github.com/1o68o7/AvSim-v1`  
Branche de travail : `feat/datar0w-mvp` (créer depuis `main`, PR vers `main`).  
App : Flutter dans `/apps/datar0w`.  
Ne pas réécrire le moteur physique AvSim (YAML, 1-DDL, FastAPI simu). S’y brancher plus tard.

---

## 0. Mission de cette session

Livrer un **MVP utilisable sur une séance d’entraînement skiff (1x)** :

1. Le téléphone est boulonné au **cale-pied**, paysage, hub de **tous les capteurs utiles du téléphone**.
2. Le **rameur** tarre la gîte, rame, voit cadence-ou-tiret / V sol / distance / gîte, stoppe, relit sa séance (replay + carte).
3. Un **entraîneur** peut **se connecter à cette séance** (code court) : live si réseau, sinon fichier dès qu’il y a un flux ou un import.

Critère de fin : `flutter run` sur un **vrai** iPhone ou Android — permissions acceptées, IMU et GPS bougent, tare à 0, fichier séance écrit, replay rameur ouvre ce fichier, coach peut entrer un code séance.

---

## 1. Agent Cursor — comment travailler

Tu es un agent dans ce repo. Ordre obligatoire :

1. Lire ce fichier en entier, puis `docs/CONVENTION-BABORD-TRIBORD.md`, `docs/CARTE-LIVE-REPLAY.md`, `docs/CURSOR-AGENT-MVP.md`.
2. `git checkout -b feat/datar0w-mvp` si la branche n’existe pas.
3. Ne pas committer sur `main` directement.
4. Commits atomiques, messages en français ou conventional commits (`feat(datar0w): ...`).
5. Ne pas porter les HTML Stitch concaténés (`datarow.html` mélange des écrans jetés). S’inspirer de l’intention des 8 écrans gelés, DA Deck, pas du pixel High-Vis.
6. Ne pas ajouter d’UI « boutique capteurs », d’Analyste, de watts, de RTK, de slip, de η.
7. Après chaque lot (capteurs / UI live / replay / coach join), commit + résumé de ce qui tourne sur device.

### Lots (faire dans l’ordre, un lot = un ou deux commits)

| Lot | Livrable |
|---|---|
| A | Scaffold Flutter `/apps/datar0w`, thème Deck, routing, README run |
| B | Permissions + services capteurs + logger brut |
| C | Écrans 1, 2A, 2B (tare 30 s) |
| D | Écran 3/4 live paysage + STOP → fichier |
| E | Écran 7 quai + replay rameur (écran 6 réduit : carte + V + distance + 2 courbes) |
| F | Code séance + join coach (local d’abord, socket/HTTP si backend dispo) |
| G | Routes FastAPI minimales `/sessions` dans l’existant **seulement si** ça ne casse pas la simu |

---

## 2. Produit — parcours rameur (séance d’eau)

```
1 Profils → 2A Config → 2B Tare gîte → 3 Live (4 = 3 + bandeau alerte)
       → STOP → 7 Quai → Replay rameur (carte + courbes)
```

| # | Écran | Format | Contenu |
|---|---|---|---|
| 1 | Profils | 390×844 | Rameur / Coach / Barreur grisé (`besoin d'un bateau barré`) |
| 2A | Pré-session | 390×844 | Classe 1x, bassin texte, GPS/IMU/BLE aucun, CTA `Continuer — tare gîte` |
| 2B | Tare | 390×844 | `0.0°`, BÂBORD gauche / TRIBORD droite, tare 30 s, Démarrer désactivé tant que ≠ OK |
| 3 | Live | **844×390** | Cadence ou `—` / V sol / distance / GÎTE / pastilles GPS IMU réseau batterie / STOP 2x |
| 4 | Alerte | 844×390 | 3 + bandeau `#E8C547` `GÎTE — trop tribords` si gîte > +3° tribords |
| 7 | Quai | 390×844 | Durée, distance GPS, cadence moy. ou `—`, gîte RMS + chip sync + Replay + Partager |
| 6r | Replay rameur | 844×390 | Même fichier : point sur la trace, V sol + distance **au curseur**, 2 courbes cadence / V sol |

Vitesse toujours légendée `sol — pas eau`.  
Gîte : réf. rameur (yeux vers la poupe) — gauche écran = BÂBORD, droite = TRIBORD.

DA : fond `#0B0E12`, chiffres blancs tabulaires, labels `#9AA0A6`, filets `#2A2F36`, alerte `#E8C547`. Pas de cyan High-Vis, pas d’onglets CONFIG/REPLAY/DEBRIEF sur le live bateau.

---

## 3. Produit — entraîneur se connecte à la séance

### Contrat MVP (pas un club SaaS)

À `Démarrer la session` le rameur obtient un **code 6 caractères** (ex. `K7P2QM`) + QR optionnel affichable au quai / écran 2B validé.

Profil **Coach** écran 1 → champ `Code séance` → Rejoindre.

Trois modes, du plus simple au plus réseau :

| Mode | Quand | Comportement |
|---|---|---|
| `local` | Même téléphone | Coach ouvre la séance en cours / la dernière. Toujours disponible. |
| `fichier` | Après STOP | Share sheet (AirDrop / Nearby / mail) du `.jsonl` séance. Coach replay = écran 6. |
| `live` | 4G/5G ou Wi-Fi | Rameur publie ~1 Hz vers l’API ; coach poll/websocket le même `session_id`. Si hors réseau : chip `en attente réseau`, le logger local continue. |

Écran coach live (5, 844×390) : carte 60 % + V sol + distance + gîte + cadence-ou-tiret + `ANNOTER` (repère : t + lat/lon + V + km).  
Même signe de gîte que le rameur + chip `réf. rameur`.

**Interdit au MVP coach :** envoyer une consigne dans le bateau, watts, diagnostic « main trop basse », RTK, splits officiels FISA.

### API minimale (lot G, optionnelle si le FastAPI local tourne)

Préfixe à ajouter **à côté** des routes simu, sans les casser :

```
POST /datarow/sessions          → { id, code }
POST /datarow/sessions/{id}/tick   body = sample 1 Hz
GET  /datarow/sessions/by-code/{code}
GET  /datarow/sessions/{id}/stream    (poll 1 s acceptable au MVP)
POST /datarow/sessions/{id}/notes
GET  /datarow/sessions/{id}/file      → jsonl complet
```

Pas d’auth OAuth au MVP. Code = secret faible de séance (expire 12 h). Documenter que ce n’est pas production-grade.

Si l’API n’est pas déployable dans la session : implémenter le client + mode `local`/`fichier`, laisser le client HTTP derrière un flag `DATAROW_API_BASE`.

---

## 4. Smartphone utilisé en entier — capteurs

Objectif : **enregistrer tout ce que le téléphone sait faire et qui sert l’aviron**, sans allumer micro / caméra (vie privée, poids, batterie).

### 4.1 À demander et à logger

| Source | Permission | Usage UI | Fichier |
|---|---|---|---|
| GPS / GNSS | Localisation quand utilisée (+ background pendant séance) | V sol, distance, point carte, pastille GPS | 1 Hz : lat, lon, alt, sog, cog, acc_h, acc_v, n_sat si dispo |
| Accéléromètre | Motion | cadence tentative, diagnostic | 50–100 Hz brut dans un sidecars *ou* 20 Hz décimé |
| Gyroscope | Motion | fusion gîte | idem |
| Magnétomètre | Motion (iOS / Android) | cap capteur vs COG GPS | 10–20 Hz si dispo |
| Attitude / rotation vector | dérivé | **gîte live** (roll − offset tare) | 20 Hz roll, pitch (pitch logué, pas affiché en gros) |
| Baromètre | Sensor (Android), CMAltimeter (iOS si dispo) | rien au live | pression + alt relative |
| Batterie | — | 62 % colonne droite | % + charging |
| Connectivité | — | chip 4G / Wi-Fi / hors ligne | type réseau |
| Horloge | — | durée | t_unix_ms |

### 4.2 Explicitement off au MVP

Micro, caméra, contacts, Bluetooth scan continu (BLE force/angle = `aucun` tant qu’on n’a pas de capteur maison), Health / FC, pedometer marketing.

BLE : stub « — aucun » prêt pour plus tard, pas de shopping UI.

### 4.3 Tare gîte

- 30 s, bateau à quai, ne pas bouger.
- Offset = moyenne du roll filtré.
- OK si écart-type < 0,2° pendant la fenêtre (sinon rester `non faite` / recommencer).
- Live : `gite_deg = roll_filtre - offset`. Affichage ±15°. Alerte si `gite_deg > +3` (tribord, droite écran).

### 4.4 Cadence

Détecteur de pics sur l’accélération longitudinale **après** tare.  
Si la période n’est pas stable 6 coups de suite → afficher `—`, ne pas inventer 28.  
Moyenne séance : uniquement sur les échantillons valides.

### 4.5 Distance / V

Distance = somme haversine entre fixes dont `acc_h < 25 m`.  
SOG = vitesse GNSS du fix, jamais « vitesse eau ».  
Si fix perdu : pastille GPS éteinte, **on n’interpole pas** la trace (trou dans le polyline).

### 4.6 Permissions à câbler (lot B)

**iOS `Info.plist`**

- `NSLocationWhenInUseUsageDescription` : *Suivi GPS de la séance d’aviron (vitesse sol et trace).*
- `NSLocationAlwaysAndWhenInUseUsageDescription` : *Continuer le suivi GPS pendant que l’écran est verrouillé au cale-pied.*
- `NSMotionUsageDescription` : *Mesure de la gîte du bateau avec l’IMU du téléphone.*
- `UIBackgroundModes` : `location`
- Orientations : portrait (1, 2A, 2B, 7) + landscape left/right (3, 4, 5, 6). Après Démarrer : lock paysage.

**Android `AndroidManifest.xml`**

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION` (demande **après** le when-in-use)
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`
- `ACTIVITY_RECOGNITION` seulement si nécessaire au plugin
- `INTERNET`, `ACCESS_NETWORK_STATE`
- Service premier plan « Séance DataR0w » tant que live.

Packages Flutter : `geolocator`, `sensors_plus`, `permission_handler`, `battery_plus`, `connectivity_plus`, `wakelock_plus` (écran allumé au cale-pied). Baromètre : plugin léger ou channel natif si `sensors_plus` ne suffit pas ; si absent sur le device, skip silencieux.

---

## 5. Fichier séance

Un dossier par séance : `/sessions/{id}/`

```
meta.json       classe, bassin, tare_offset, code, started_at, phone_model
samples.jsonl   1 Hz UI / carte / coach
imu.jsonl       optionnel, 20 Hz compact (t, ax,ay,az, gx,gy,gz, roll, pitch)
notes.json      annotations coach / rameur
```

Ligne `samples.jsonl` :

```json
{"t": 1710000000123, "lat": 48.99, "lon": 1.70, "alt": 22.1,
 "sog": 4.21, "cog": 187.0, "acc_h": 4.8,
 "dist_m": 1240.2, "gite_deg": 1.4, "pitch_deg": 0.2,
 "cadence_spm": null, "batt": 62, "net": "4g"}
```

C’est la source unique de 5, 6, 6r, 7.

---

## 6. Architecture repo

```
/apps/datar0w/                 # Flutter (nouveau)
  lib/
    main.dart
    theme/deck_theme.dart
    sensors/{permissions,gps,imu,battery,net,logger}.dart
    session/{model,store,code,api_client}.dart
    features/profile/          # écran 1
    features/presession/       # 2A
    features/tare/             # 2B
    features/live/             # 3 + overlay 4
    features/quai/             # 7
    features/replay/           # 6r rameur + 6 coach
    features/coach/            # join + 5 live
  README.md                    # flutter run, permissions, cale-pied paysage
/docs/                         # cadrage (ne pas écraser STATE.md à la légère)
# backend existant : ajouter /datarow/* seulement au lot G
```

State : Riverpod. Routes : go_router.  
Carte : `flutter_map` + OSM tuiles sombres **ou** canvas polyline seul si tuiles pèsent. Pas de Google Maps clé au MVP.

Lien AvSim : aucun appel simu pendant le live. Un import séance → outil labo peut venir **après** le MVP eau.

---

## 7. Hors contrat (ne pas coder)

- RTK, 10 Hz GNSS pro, « LOCK 0.4 m »
- Watts, η, slip, YAML, console Analyste
- Barreur 4+/8+
- Couloirs FISA / splits officiels sans GeoJSON bassin
- Micro / caméra / coaching vocal
- Pixel-perfect des HTML Stitch rejetés
- Refonte du solveur AvSim

---

## 8. Definition of done (séance device)

Sur téléphone réel, ciel ouvert :

1. Dialogues Localisation + Mouvements. Refus → 2A bloque avec texte clair, pas de crash.
2. 2B : incliner le tel, `0.0` bouge ; tare 30 s ; Démarrer s’active ; inclinaison revient autour de 0.
3. Live paysage : SOG et km avancent en marchant / à vélo de test ; gîte suit le roll ; STOP 2 appuis → fichier non vide.
4. 7 affiche durée / km / gîte RMS.
5. Replay rameur : curseur déplace le point, V et distance suivent l’instant.
6. Coach : saisir le code de la séance locale → voit les mêmes chiffres (mode `local` au minimum).
7. `apps/datar0w/README.md` explique run iOS/Android et le montage paysage cale-pied.
8. Branche poussée, PR décrite.

---

## 9. Prompt agent (bloc à coller)

```
Read docs/CURSOR-SESSION-MVP-RAMEUR.md fully and implement Lot A then B of DataR0w in this AvSim-v1 repo.

Create branch feat/datar0w-mvp from main if needed.
Scaffold Flutter app at /apps/datar0w with Deck theme and go_router.
Do not rewrite AvSim physics. Do not copy rejected Stitch HTML.

Lot A: project + theme + empty routes for screens 1, 2A, 2B, 3, 7, replay, coach-join.
Lot B: permission_handler + geolocator + sensors_plus + battery_plus + connectivity_plus.
On a real device, print / overlay raw GPS and roll. Implement session logger skeleton (samples.jsonl).

Commit after each lot. French UI strings. Heel: left = BÂBORD, right = TRIBORD.
Speed caption: sol — pas eau. Cadence may be null.
When A+B run on device, stop and summarize remaining lots C–G from the same doc.
```
