# Stroke sensor DIY — capteur maison (acc + gyro + stroke + gîte)

> **Statut** : cadrage produit. Décision figée : **on ne prend PAS de solution du marché** (NK StrokeCoach, BioRow, SpeedCoach). On construit le capteur nous-mêmes — c'est le produit AvSim.
> **Date** : 2026-09-30
> **Contexte** : retour rameuse compétition — cadence_spm trop imprécis dans les apps (CrewNerd, CrewWatch). Vérif QEPSSL : `cadence_src` null partout (32 samples + 574 lignes IMU). Détection a posteriori sur ax : ~48 spm, SNR 1.1, CV intervalles 47 %. Le téléphone en poche/ponton ne rattrapera jamais un capteur rigger.
> **Prérequis** : docs/CADRAGE-CARDIO-BLE-RAMEUR.md (point R, FC BLE) et docs/CADRAGE-TELEMETRIE-TEL.md (télémétrie téléphone) mergés.

---

## 1. Décision produit

| # | Décision | Détail |
|---|---|---|
| S1 | Pas de solution marché | NK StrokeCoach (~150 €), BioRow, SpeedCoach : fermés, chers, pas de protocole ouvert. Coût cible DIY : **10–20 €** unitaire (×20 rameurs = 200–400 € vs 3000 € marché). |
| S2 | Une puce, plusieurs mesures | Pas de puce unique « tout-en-un » : on compose une stack (IMU + SoC BLE). C'est exactement ce que NK/BioRow font. |
| S3 | Position = téléphone | Pas de GPS dans le clip (précision 10 m, autonomie, signal sous arbres). Le capteur envoie le timestamp du coup ; l'app corrèle avec le GPS du téléphone. |
| S4 | Protocole ouvert | Format BLE documenté, licence MIT, implémentable par n'importe qui. C'est ça qui tue NK. |
| S5 | Validation avant prototype | L'algo de détection de coup doit être validé sur le banc AvSim avec séances réelles avant de commander les premiers PCB. |

---

## 2. Sourcing (vérifié)

### 2.1 IMU : Bosch BMI323

Six axes, 16 bits, boîtier 2.5 × 3 mm :

| Axe | Plage | Résolution | Bruit |
|---|---|---|---|
| Accéléromètre | ±2 à ±16 g | 16 bits | 180 µg/√Hz |
| Gyroscope | ±125 à ±2000 °/s | 16 bits | 0.007 °/s/√Hz |

- Température intégrée, FIFO 2 Ko, 2 interruptions programmables.
- Consommation : 790 µA haute performance.
- **Rôle** : acc = détection du coup (pic ax) ; gyro = gîte / pitch du bateau.

Alternative : ST **LSM6DSOX** (550 µA, FIFO 9 Ko, machine learning core embarquée) — plus cher, plus de fonctions, mais le BMI323 est plus sobre et plus simple à driver.

### 2.2 Cerveau : Nordic nRF52840

- SoC BLE 5 + Cortex-M4 64 MHz, 1 Mo flash, 256 Ko RAM.
- Lit l'IMU en I2C/SPI, fait la détection de coup en firmware, envoie le paquet BLE.
- Veille : **0.4 µA** → 6 mois sur CR2032.

Alternative budget : **ESP32-C3** (~3 €) — mais Wi-Fi inutile embarqué, consommation plus haute. À garder pour un prototype rapide si le nRF52840 tarde.

### 2.3 Position : téléphone uniquement

GPS dans un clip d'aviron = mort : précision 10 m, pas d'autonomie, pas de signal sous les arbres. Le capteur envoie le timestamp du coup, l'app fait la corrélation avec le GPS.

### 2.4 Alim / mécanique

- Pile **CR2032**, autonomie cible 6 mois.
- Boîtier clip sur l'aviron, étanche, **< 30 g**.
- PCB : 2 couches, ~20 × 30 mm.

---

## 3. Protocole BLE ouvert (proposition v0.1)

### 3.1 Service / characteristics

| Élément | UUID | Notes |
|---|---|---|
| Service | `0xA000` (custom, à figer) | 128-bit si besoin : `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` (Nordic UART-like) |
| Char stroke | `0xA001` | Notify : paquet coup |
| Char battery | `0x2A19` (SIG standard) | Read : % pile |
| Char device info | `0x180A` | Read : nom, firmware |

### 3.2 Paquet stroke (notify, 12 octets)

```
Offset 0  : t_ms        uint32  timestamp ms (epoch ou session-relative)
Offset 4  : stroke_count uint16 compteur de coups (wrap 65536)
Offset 6  : ax_peak     int16   pic acc x (mg) au moment du coup
Offset 8  : gite_deg    int16   gîte estimée (×100, signe bâbord-)
Offset 10 : battery     uint8   % pile
Offset 11 : flags       uint8   bit0=gyro_valid, bit1=gite_valid
```

Fréquence d'envoi : **1 paquet par coup** (pas de stream continu — économie pile).

### 3.3 Détection de coup (firmware)

1. Lire ax à 100–200 Hz depuis le FIFO BMI323.
2. Seuil : `|ax| > SEUIL_MG` (à calibrer, typiquement 1500–2500 mg selon le montage).
3. Fenêtre réfractaire : 800 ms minimum entre deux coups (empêche les rebonds).
4. Enregistrer t_ms + ax_peak, pousser dans la file BLE.
5. Gîte : moyenne gyro z sur 200 ms autour du pic (signe bâbord- selon CONVENTION-BABORD-TRIBORD.md).

### 3.4 Licence

MIT. Le protocole est documenté ici ; n'importe qui peut l'implémenter (autre capteur, autre app).

---

## 4. Architecture app (apps/datar0w)

```
lib/sensors/stroke/
  stroke_scanner.dart   // scan GATT service 0xA000 via flutter_blue_plus
  stroke_parser.dart    // parse paquet 12 octets → StrokeEvent
  stroke_hub.dart       // stream StrokeEvent → LiveHub
lib/session/stroke_store.dart  // appareils appairés (id, name, lastSeen)
```

- `StrokeHub` expose `Stream<StrokeEvent>` → `LiveHub` l'injecte : `cadence_spm` recalculé sur fenêtre glissante 10 s, `cadence_src = 'stroke_sensor'`.
- Sans capteur : `cadence_src = null` → UI affiche **« cadence non mesurée »** (pas de tiret, pas de 0, pas d'estimation IMU).
- FC : réutilise le point R (`0x180D`, sangle pectorale). `hr_source = 'ble_strap'`.
- Permissions Android 12+ : `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`.

### 4.1 Extension SessionSample (rétro-compatible)

```dart
class SessionSample {
  // ... existant
  final double? cadenceSpm;   // null si pas de capteur
  final String? cadenceSrc;   // 'stroke_sensor' | 'ble_strap' | null
  final int? hrBpm;           // point R
  final String? hrSource;     // point R
}
```

Champs optionnels : une séance sans capteur reste un JSONL valide.

---

## 5. Validation sur le banc AvSim (avant prototype)

1. **Jeu de séances réelles** : QEPSSL + GT9JDK + GCZEKF (déjà en Storage) + nouvelles sorties 1x/2x/4x/8+.
2. **Algo de référence** : détection pic ax sur IMU téléphone (SNR, CV intervalles) — baseline à battre.
3. **Critères de validation** :
   - Erreur cadence vs capteur de référence (StrokeCoach loué ou vidéo comptée) : **< 2 spm** en régime stable.
   - Détection des coups manqués : < 1 %.
   - Faux positifs (bruit, vagues) : < 1 %.
   - Gîte : écart < 2° vs IMU téléphone tareé.
4. **Seuil SEUIL_MG** : balayage 1000–4000 mg, choix du minimum d'erreurs.
5. **Rapport** : `docs/RAPPORT-VALIDATION-STROKE-SENSOR.md` avec courbes et chiffres.

---

## 6. Lots de build (ordre)

| Lot | Contenu | Commit |
|---|---|---|
| **S1** | `flutter_blue_plus` + scan GATT `0xA000` + parse paquet 12 octets + store appareils. Tests parseur. **Aucun écran.** | `feat(datar0w): stroke sensor BLE parser + hub` |
| **S2** | `StrokeHub` → `LiveHub`, `cadence_src = 'stroke_sensor'`, chip live discret. | `feat(datar0w): stroke cadence chip live` |
| **S3** | UI « cadence non mesurée » (pas de tiret/0), écran `/stroke/pair`. | `feat(datar0w): cadence honnête + pair screen` |
| **S4** | Firmware nRF52840 (détection coup, paquet BLE, veille 0.4 µA) — repo séparé `AvSim-stroke` ou dossier `firmware/stroke/`. | `feat(stroke): nrf52840 firmware v0.1` |
| **S5** | Validation banc AvSim (S5 ci-dessus) + rapport. | `docs: rapport validation stroke sensor` |
| **S6** | Sync cloud : cadence dans samples serveur, visible coach. | `feat(datar0w): stroke cadence sync cloud` |

**S1 et S2 = MVP utile.** S3 = honnêteté UX. S4–S6 = produit complet.

---

## 7. Hors scope (volontaire)

- Solutions marché (NK, BioRow, SpeedCoach) — décision S1.
- ANT+ (trop de friction Android).
- GPS dans le capteur (décision S3).
- SDK propriétaire.
- Sync session_meta, Google OAuth, Stitch, #50, secrets.

---

## 8. Prompt Cursor (à coller, lot S1 d'abord)

```
Stroke sensor DIY — lot S1 (aucun écran).
Lis docs/CADRAGE-STROKE-SENSOR-DIY.md, docs/CADRAGE-CARDIO-BLE-RAMEUR.md,
docs/CADRAGE-TELEMETRIE-TEL.md, docs/CONVENTION-BABORD-TRIBORD.md.
Ne pas toucher AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets.
compileSdk 37, NDK 30.0.16248370. Pas de sdkmanager. Pas de windows/.

1) flutter_blue_plus déjà en dep — vérifier version lockée (pubspec.lock).
2) lib/sensors/stroke/ :
   - stroke_scanner.dart : scan filtré service 0xA000 (128-bit si besoin),
     permissions Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_CONNECT).
   - stroke_parser.dart : parse paquet 12 octets (t_ms uint32, stroke_count
     uint16, ax_peak int16 mg, gite_deg int16 ×100, battery uint8, flags uint8).
     Tests unitaires : 3 payloads (coup normal, wrap compteur, flags gyro) →
     StrokeEvent corrects.
   - stroke_hub.dart : stream StrokeEvent {tMs, strokeCount, axPeak,
     giteDeg, battery}.
3) stroke_store.dart : appareils appairés (id, name, lastSeen) en JSON local
   (Documents/datar0w/stroke_devices.json).
4) SessionSample : ajouter cadenceSpm (double?), cadenceSrc (String?) —
   optionnels, rétro-compat (absent = null).
5) Ne PAS brancher l'UI dans ce lot. Juste le hub + tests.
6) flutter analyze clean. Tests parseur verts.

Commit : feat(datar0w): stroke sensor BLE parser + hub
Stop si analyze casse. Pas de PR fourre-tout.
```

---

## 9. À discuter avant de coder

1. **Seuil SEUIL_MG** : 1500 mg (sensible, faux positifs vagues) ou 2500 mg (robuste, coups faibles manqués) ? → À trancher après validation S5.
2. **Fenêtre réfractaire** : 800 ms fixe ou adaptative (fonction de la cadence) ? → Recommandation : adaptative après 2 min de régime.
3. **Gîte dans le paquet** : on l'envoie (gain : gîte rigger vs téléphone) ou on la calcule côté app depuis l'IMU téléphone ? → Recommandation : envoyée (plus fiable, le capteur est sur l'aviron).
4. **Multi-capteurs** : 1 capteur = 1 aviron. Pour un 8+, on pair N capteurs ? → Recommandation : MVP = 1 capteur (le rameur du siège 1), multi plus tard.

---

*Fin du cadrage stroke sensor DIY. Rien n'est codé tant que S1 n'est pas lancé.*
