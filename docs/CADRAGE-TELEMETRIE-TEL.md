# Cadrage — télémétrie smartphone seule

*Lot suivant DataR0w. Aucun capteur d’aviron, aucune sonde bateau, pas de RTK externe.*
Réf. audit : `docs/AUDIT-FONCTIONS-CAPTEURS.md`. Ne pas revert `compileSdk = 37` / NDK 30.

Objectif : une sortie 1x où le OnePlus au cale-pied **reste lisible**, **continue à logger** si l’écran se verrouille, et écrit tout ce que le téléphone peut donner sans mentir.

---

## 1. Ce qui suffit pour un MVP opérationnel

Sans matériel externe, le contrat utile est :

| Grandeur | Source tel | Live | Fichier | Statut |
|---|---|---|---|---|
| V sol | GNSS SOG | oui | `sog` | déjà |
| Distance | haversine | oui | `dist_m` | déjà |
| Trace | lat/lon | replay / coach | jsonl | déjà |
| Cap sol | GNSS COG | option live | `cog` | logué, peu affiché |
| Gîte | gyro+acc − tare | oui | `gite_deg` | déjà |
| Tangage | même IMU | discret | `pitch_deg` | logué |
| Qualité fix | `acc_h` | pastille | oui | déjà |
| Batt / réseau | OS | pastilles | oui | déjà |
| Écran allumé | wakelock | — | — | **à faire** |
| Logger écran off | FGS + background loc | — | jsonl | **à faire** |

Avec ça + tare + STOP + replay + partage, un entraîneur peut débriefer **sans** 2e tel et **sans** boîtier NK / Peach / Empacher.

---

## 2. Lot à intégrer (priorité)

### P0 — sans ça le cale-pied est inutilisable

**Wakelock**  
- `wakelock_plus` : enable à Démarrer, disable à STOP / dispose.  
- Ne pas laisser le lock hors séance (batterie).  
- Option : luminosité max pendant le live (plein soleil).

**Séance survivante (GPS + IMU)**  
Le manifeste déclare déjà `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` — **aucun service n’est déclaré**, `permissions.dart` ne demande que when-in-use.

À faire :
1. Permission when-in-use d’abord, **puis** background (ordre Android 10+).  
2. `flutter_foreground_task` (ou équivalent) type `location`.  
3. Notification persistante « DataR0w — séance » entre Démarrer et STOP.  
4. Déclarer le `<service>` dans le manifeste.  
5. Le tick 1 Hz et l’IMU tournent dans ce service, pas seulement dans le widget visible.

Sans P0 : écran noir + trous GPS dès que OxygenOS endort l’app.

### P1 — télémétrie tél. encore inutilisée (log, pas forcément UI)

**Magnéto** (`sensors_plus` magnetometer)  
- Colonne `hdg_mag` (degrés, 0–360) dans `samples.jsonl`.  
- Comparer à `cog` GPS quand SOG > 1 m/s = dérive / dérapage grossier.  
- Ne **pas** remplacer le COG par le magnéto (fer du bateau + calage tel).  
- UI live : optionnel, petit cap ; sinon fichier seulement.

**Baro**  
- OnePlus 9 a en général un baromètre. API : `sensors_plus` `barometerEventStream` uniquement.  
  **Ne pas** ajouter `environment_sensors` (jcenter cassé sous AGP 9 / Gradle 9).  
- Colonnes `p_hpa` + `alt_baro` relative à la tare (quai = 0).  
- Utile en replay (creux de vague / faux plat), **pas** pour V.  
- Si capteur / API absents : `null`, pas d’erreur.

**Cadence tél. (option prudente)**  
- Ne jamais afficher un SPM instable.  
- Détecteur : pics d’accélération longitudinale, période médiane sur **6 coups** stables (écart < 15 %).  
- Sinon rester `cadence_spm: null` / `—`.  
- Label : `estim. tel` pour ne pas passer pour un capteur d’aviron.  
- Hors scope si l’algo n’est pas validé sur 2 sorties réelles.

### P2 — 2e téléphone (pas bloquant bassin)

API `DATAROW_API_BASE` + routes FastAPI `/datarow/*` (Lot G).  
MVP bassin = **Partager** le jsonl (WhatsApp / Drive) + replay sur le tel coach. G vient après P0.

---

## 3. Autre télémétrie possible sur le smartphone — on prend / on laisse

| Signal | Prendre ? | Pourquoi |
|---|---|---|
| GNSS brut 1 Hz (déjà) | oui | cœur |
| NMEA / dual-freq brut | non | API constructeur, pas portable |
| Rotation vector / game rotation | oui si plus stable que fusion maison | peut remplacer le complémentaire |
| Pitch (déjà logué) | oui | garder |
| Yaw magnéto | P1 | cap capteur |
| Accéléro linéaire 20–50 Hz dans `imu.jsonl` | déjà brut | garder |
| Step detector / pedometer | non | faux à bord |
| Activity Recognition | non | |
| Lumière ambiante | non | |
| Proximité | non | |
| Micro / caméra / FC | **interdit** | |
| BLE scan | plus tard | aide à l’achat, pas télémétrie séance |
| Cell-ID / Wi-Fi RTT | non | |
| Température batterie | option log | diagnostic |
| Vibration alerte gîte | **oui petit plus P0** | rameur ne lit pas toujours |
| Verrouillage paysage live | **oui P0** | `SystemChrome` + capteur orientation |
| GeoJSON bassin | P2 | carte marche sans |

Rien d’autre sur un OnePlus 9 n’apporte une grandeur d’aviron fiable sans capteur externe (pas de force, pas de slip, pas de V eau).

---

## 4. Schéma jsonl étendu (compat)

Lignes actuelles inchangées. Ajouts **optionnels** :

```
hdg_mag, p_hpa, alt_baro, cadence_src  // "tel" | null
```

Lecteurs replay ignorent les clés inconnues.

---

## 5. Hors cadrage (toujours)

Watts, η, slip, RTK, 10 Hz GNSS affiché, vitesse surface, Barreur 4+, moteur AvSim, Windows desktop, High-Vis.

---

## 6. Prompt Cursor (Lot P0 puis P1)

```
Lot télémétrie tél. seule. Lis docs/CADRAGE-TELEMETRIE-TEL.md.
Ne recrée pas l’app. Ne touche pas AvSim. Garde compileSdk 37 et ndkVersion 30.0.16248370.

P0:
- wakelock_plus : lock Démarrer → STOP
- landscape lock écrans 3/4
- Foreground service location + notification « séance »
- Demander background location APRÈS when-in-use
- Déclarer le <service> (le manifeste a déjà les permissions)
- Vibration courte sur bandeau gîte
- Logger 1 Hz + IMU doivent survivre écran off

P1 (si P0 vert):
- magnetometer → hdg_mag nullable
- baro → p_hpa / alt_baro nullable
- cadence tel seulement si 6 coups stables, sinon —

Pas de Lot G dans ce commit.
Commit: feat(datar0w): wakelock + FGS + capteurs tél. P1
```

---

## 7. Recette bassin

1. Démarrer → écran reste allumé 2 min sans toucher.  
2. Verrouiller le tel 1 min, ramer / marcher : `samples.jsonl` continue (timestamps sans trou > 3 s).  
3. STOP → replay trait continu.  
4. Batterie : noter % / 20 min.  
