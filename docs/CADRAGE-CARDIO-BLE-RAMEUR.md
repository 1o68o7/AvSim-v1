# Point R — Cardio BLE pour le dashboard rameur

> **Statut** : cadrage exploratoire. Aucun code. À discuter avant de coder.
> **Prérequis** : point H (Riverpod + repositories) mergé. Sinon on ne touche pas.
> **Date** : 2026-09-20

---

## 1. Constat (vérifié en live)

### 1.1 Le téléphone ne mesure PAS le cardio

Le OnePlus 9 (et la plupart des Android) **n'a pas** de capteur SpO2 optique.
`sensors_plus` ne couvre que accéléro / gyro / mag / baro — **pas** de fréquence cardiaque, **pas** de saturation.

Donc : impossible de lire HR / SpO2 depuis le téléphone seul. Il faut un **capteur externe BLE**.

### 1.2 Les capteurs BLE existent et sont standardisés

| Métrique | Profil GATT SIG | UUID service | Fiabilité aviron |
|---|---|---|---|
| Fréquence cardiaque | Heart Rate Service | `0x180D` | ✅ Excellent (sangle pectorale) |
| SpO2 | Pulse Oximeter Service | `0x1822` | ⚠️ Moyen (oximètre doigt / montre) |

- **Sangle pectorale** (Polar H10, Garmin HRM-Pro, Wahoo TICKR) : ECG, précis même en sprint, double BLE+ANT+. **C'est le standard aviron.**
- **Brassard optique** (Polar Verity Sense) : bon compromis, porté sur l'avant-bras.
- **Montre au poignet** : **à éviter en aviron** — le mouvement du poignet (attrape / lâcher de la pelle) fait dériver la lecture optique (erreur ~13 % en aviron vs ~4 % en marche, études comparatives). Cadence 30–32 spm peut être lue comme 170+ bpm.
- **Oximètre doigt** : SpO2 ponctuel, pas de stream continu fiable en mouvement.

### 1.3 Ce que font les apps aviron existantes

- Concept2 PM5 : reçoit la FC via BLE/ANT+, l'affiche sur l'écran, la pousse dans ErgData.
- ErgData / RowAlong : pairent une sangle, streament la FC.
- **Aucune app aviron ne lit le SpO2 en continu** pendant la course — c'est un marqueur de récupération / altitude, pas de performance live.

---

## 2. Décisions figées (à valider)

| # | Décision | Recommandation |
|---|---|---|
| R1 | Source cardio | **BLE externe uniquement** (sangle / brassard). Jamais le téléphone. |
| R2 | Métrique prioritaire | **FC en continu** (1 Hz). SpO2 = **ponctuel / optionnel**, pas bloquant. |
| R3 | Appareils supportés (MVP) | Profils GATT standard : `0x180D` (FC), `0x1822` (SpO2). Marques : Polar, Garmin, Wahoo, génériques. **Pas** de SDK propriétaire (Polar SDK, Garmin GFDI) au MVP. |
| R4 | Où afficher | Dashboard rameur `/live` : chip discret FC + SpO2 (si dispo), **sans** pousser le layout. Courbe FC en replay. |
| R5 | Persistance | FC + SpO2 dans `samples.jsonl` (1 Hz) **si capteur branché**, sinon champs absents (rétro-compat). Sync cloud au point B. |
| R6 | Consentement / santé | Opt-in explicite. Mention « données de santé, usage informatif, pas médical ». Pas de diagnostic, pas d'alerte médicale. |
| R7 | Multi-appareil | 1 sangle = 1 rameur. Le coach **voit** la FC du rameur via l'API (point G / Lot G), pas en direct BLE (le BLE est local au téléphone du rameur). |
| R8 | Hors scope MVP | ANT+ (Android le gère mal), ECG, HRV avancé, SpO2 médical, montre Apple (ne broadcaste pas en BLE HRM natif). |

---

## 3. Modèle de données

### 3.1 Extension `SessionSample` (rétro-compatible)

```dart
class SessionSample {
  // ... existant (lat, lon, vSol, dist, gite, ...)
  final int? hrBpm;      // null si pas de capteur
  final int? spo2Pct;    // null si pas de capteur / pas de lecture
  final String? hrSource; // "ble:Polar H10" | null
}
```

Champs **optionnels** : une séance sans capteur reste un JSONL valide.

### 3.2 Store capteur (local)

```dart
class CardioDevice {
  final String id;          // MAC / UUID BLE
  final String name;        // "Polar H10"
  final bool supportsHr;
  final bool supportsSpo2;
  final DateTime? lastSeen;
}
```

Persistance : `Documents/datar0w/cardio_devices.json` (appareils appairés).

---

## 4. Architecture (s'appuie sur le point H)

```
lib/sensors/ble/
  ble_scanner.dart      // scan GATT 0x180D / 0x1822 via flutter_blue_plus
  hr_parser.dart        // parse 0x2A37 (flags + BPM 8/16 bits)
  spo2_parser.dart      // parse 0x2A5F (Pulse Oximeter)
  cardio_hub.dart       // stream unifié → LiveHub
lib/session/cardio_store.dart   // appareils appairés + prefs
```

- `CardioHub` expose `Stream<CardioReading>` → `LiveHub` l'injecte dans le sample 1 Hz.
- Si déconnexion BLE : `hrBpm = null`, chip « FC — », **pas d'erreur bloquante**.
- Permissions Android 12+ : `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (+ localisation si scan legacy).

---

## 5. UX (DA Deck, #0B0E12)

**Live `/live` (rameur)**  
Chip discret en haut, à côté de la gîte :  
`♥ 142` (vert si < seuils, ambre si zone 4, rouge si > 180) + `SpO2 97%` si présent.  
Pas de gros chiffre, pas de push layout. Tap → mini-panneau (batterie capteur, nom appareil).

**Replay**  
Courbe FC en 2ᵉ axe (comme la gîte), SpO2 en pastilles ponctuelles.

**Coach `/coach`**  
Si l'API live (Lot G) transmet `hrBpm`, affichage en chip sur la fiche rameur.  
Sinon « — » (le coach ne pair pas le BLE lui-même).

**Pairing**  
Écran dédié `/cardio/pair` (accessible depuis profil ou 2A) : scan, liste, « Appairer ».  
Mémorise le dernier appareil.

---

## 6. Lots de build (ordre)

| Lot | Contenu | Commit |
|---|---|---|
| **R1** | `flutter_blue_plus` + scan GATT `0x180D` + parse FC + store appareils. Tests parseur (flags 8/16 bits). **Aucun écran.** | `feat(datar0w): ble heart-rate GATT parser` |
| **R2** | `CardioHub` → `LiveHub`, champs `hrBpm`/`spo2Pct` dans sample, chip live discret. | `feat(datar0w): cardio chip live + sample fields` |
| **R3** | SpO2 GATT `0x1822` (optionnel), pastilles replay, écran `/cardio/pair`. | `feat(datar0w): spo2 optional + pair screen` |
| **R4** | Sync cloud (point B) : `hr_bpm`, `spo2_pct` dans samples serveur, visible coach. | `feat(datar0w): cardio sync cloud` |
| **R5** | Courbe FC replay, zones colorées, export. | `feat(datar0w): hr replay curve + zones` |

**R1 et R2 = MVP utile.** R3–R5 = confort.

---

## 7. Hors scope (volontaire)

- ANT+ (trop de friction Android, faible valeur vs BLE).
- SDK propriétaire Polar / Garmin (maintenance lourde, pas de gain vs GATT).
- Diagnostic médical, alertes « urgence », seuils cliniques.
- SpO2 en continu temps réel (irréaliste en mouvement d'aviron).
- Montre Apple Watch comme source (ne broadcaste pas en BLE HRM sans app tierce).
- Intégration Concept2 PM5 / FTMS (autre chantier, point à part).

---

## 8. Prompt Cursor (à coller, lot R1 d'abord)

```
Point R1 — BLE Heart Rate GATT (aucun écran).
Lis docs/CADRAGE-CARDIO-BLE-RAMEUR.md et docs/CADRAGE-ARCHITECTURE.md.
Prérequis H1–H3 mergés. Ne pas toucher AvSim. compileSdk 37, NDK 30.0.16248370.
Pas de sdkmanager. Pas de windows/.

1) Ajouter flutter_blue_plus au pubspec (remplacer tout ancien flutter_blue).
2) lib/sensors/ble/ :
   - ble_scanner.dart : scan filtré service 0x180D, permissions Android 12+
     (BLUETOOTH_SCAN, BLUETOOTH_CONNECT) + localisation si legacy.
   - hr_parser.dart : parse 0x2A37 (byte flags : bit0=16bits, bit1=contact,
     bit3=energy, bit4=RR). Gérer 8 et 16 bits. Tests unitaires : 3 payloads
     (8-bit, 16-bit, avec RR) → bpm corrects.
   - cardio_hub.dart : stream CardioReading {hrBpm, contact, battery?}.
3) cardio_store.dart : appareils appairés (id, name, lastSeen) en JSON local.
4) SessionSample : ajouter hrBpm (int?), hrSource (String?), spo2Pct (int?) —
   tous optionnels, rétro-compat (absent = null, pas d'erreur).
5) Ne PAS brancher l'UI dans ce lot. Juste le hub + tests.
6) flutter analyze clean. Tests parseur verts.

Commit : feat(datar0w): ble heart-rate GATT parser + cardio hub
Stop si analyze casse. Pas de PR fourre-tout.
```

---

## 9. À discuter avant de coder

1. **SpO2** : on le garde optionnel (R2) ou on le retire du MVP ?  
   → Recommandation : **optionnel**, ne pas bloquer R1/R2.
2. **Seuils d'alerte FC** : zones fixes (180/190) ou personnalisables par rameur ?  
   → Recommandation : fixes au MVP, perso plus tard.
3. **Visibilité coach** : le coach voit la FC live du rameur (via API) ou seulement en replay ?  
   → Recommandation : **live via API** (point G), c'est le vrai plus-value coaching.
4. **Batterie du capteur** : on l'affiche ou on s'en fiche ?  
   → Recommandation : chip discret, pas prioritaire.

---

*Fin du point R. Rien n'est codé tant que H n'est pas mergé et que R1–R4 ne sont pas tranchées.*
