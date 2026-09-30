# Patch coque autonome FFA — gîte + baro + T/H + mémoire (sans téléphone)

> **Statut** : cadrage produit. Décision figée : **on ne prend PAS de solution du marché** (NK, BioRow, SpeedCoach). On construit le capteur nous-mêmes — c'est le produit AvSim.
> **Date** : 2026-09-30
> **Contexte** : besoin compétiteur FFA — téléphone interdit en course. Le capteur d'aviron (docs/CADRAGE-STROKE-SENSOR-DIY.md) couvre le coup. Il manque le **gîte de coque** et la **définition de parcours** (pression, vent, température, humidité) sans radio ni téléphone.
> **Prérequis** : docs/CADRAGE-STROKE-SENSOR-DIY.md (stroke sensor DIY), docs/CADRAGE-TELEMETRIE-TEL.md (télémétrie téléphone), docs/CONVENTION-BABORD-TRIBORD.md.

---

## 1. Décision produit

| # | Décision | Détail |
|---|---|---|
| P1 | Patch coque autonome | Un seul boîtier collé à plat sur la coque. Zéro téléphone, zéro radio, zéro installation bateau. Interdit FFA respecté. |
| P2 | Pas de GPS dans le patch | GPS = précision 10 m, pas d'autonomie, signal sous arbres. La position vient du téléphone **hors course** (entraînement) ou d'un GPS externe séparé (hors scope). |
| P3 | Vent = R&D ouverte | Pas de puce vent. Girouette mécanique = invasif (mât, câblage). À étudier séparément (voir §7). |
| P4 | Propeller = hors scope pour l'instant | Un hélice sous la coque = percement, drag, maintenance. Le moins invasif = rien sous la ligne de flottaison. À rouvrir si besoin de vitesse eau. |
| P5 | Mémoire locale obligatoire | Le patch stocke tout en flash. Récupération post-course par USB ou NFC. Pas de BLE en course (interdit FFA). |
| P6 | Validation avant prototype | Même règle que le stroke sensor : valider l'algo gîte sur le banc AvSim avant de commander des PCB. |

---

## 2. Sourcing (vérifié)

### 2.1 IMU : Bosch BMI323 (déjà retenu pour le stroke sensor)

Six axes, 16 bits, boîtier 2.5 × 3 mm :

| Axe | Plage | Résolution | Bruit |
|---|---|---|---|
| Accéléromètre | ±2 à ±16 g | 16 bits | 180 µg/√Hz |
| Gyroscope | ±125 à ±2000 °/s | 16 bits | 0.007 °/s/√Hz |

- **Rôle ici** : gyro = gîte et pitch de la coque (le patch est à plat, le gyro z mesure la rotation autour de l'axe longitudinal du bateau).
- Consommation : 790 µA haute performance.
- Alternative : ST LSM6DSOX (550 µA, FIFO 9 Ko) — plus cher, plus de fonctions.

### 2.2 Pression atmosphérique : Bosch BMP390

- Plage : 300–1250 hPa, résolution 0.016 Pa (altitude ~10 cm).
- Bruit : 0.03 Pa RMS.
- Consommation : ~3.2 µA en mode basse puissance (1 Hz), ~260 µA en mode continu 200 Hz.
- **Rôle** : pression = altitude barométrique (dénivelé du parcours) + tendance météo.
- Prix : ~3 € l'unité.

### 2.3 Température + humidité : Sensirion SHT40

- Plage T : -40 à +125 °C, résolution 0.01 °C.
- Plage HR : 0–100 % RH, résolution 0.01 %.
- Consommation : ~0.4 µA en veille, ~1.8 µA en mesure (1 Hz).
- **Rôle** : température et humidité de l'air (densité de l'air = résistance aérodynamique).
- Prix : ~2 € l'unité.

### 2.4 Vent : PAS de puce (R&D ouverte)

- Aucun capteur de vent en puce SMD n'existe. Les solutions marché : girouette-anémomètre mécanique (invasif : mât, câblage, ~50–150 €) ou estimation par pression différentielle (fragile, bruit).
- **Décision** : hors scope du patch v0.1. Lot R&D séparé (voir §7).

### 2.5 Cerveau : Nordic nRF52840 (même SoC que le stroke sensor)

- SoC BLE 5 + Cortex-M4 64 MHz, 1 Mo flash, 256 Ko RAM.
- Veille : 0.4 µA.
- **Rôle ici** : lit l'IMU + BMP390 + SHT40 en I2C, écrit en flash externe, pas de BLE en course.
- Alternative budget : ESP32-C3 (~3 €) — à garder pour prototype rapide.

### 2.6 Mémoire : flash externe SPI W25Q64

- 64 Mo, ~1 €.
- À 10 Hz, une journée de régate (~6 h) = ~2.2 millions de lignes × ~24 octets = ~52 Mo. **64 Mo suffit pour une journée complète.**
- Alternative : W25Q128 (128 Mo, ~1.5 €) si on veut 2 jours.

### 2.7 Alim

- CR2032 : **insuffisant** pour une journée à 10 Hz en continu (courant moyen ~1 mA → 240 mAh nécessaire, CR2032 = 220 mAh max, marge nulle).
- **Solution** : pile lithium rechargeable LiPo 300–500 mAh (~2–3 €) + charge USB-C. Ou panneau solaire souple (~5 €) en appoint.
- Cible autonomie : **une journée de régate complète** (6–8 h) sans recharge.

### 2.8 Mécanique

- Boîtier : résine époxy ou ABS avec **potting complet** (pas de joint torique seul — l'eau s'infiltre).
- Fixation : **adhésif double face marin** (3M VHB) + vis de secours. Rien de perçant, rien sous la ligne de flottaison.
- Poids cible : < 50 g.
- Dimensions : ~40 × 30 × 10 mm.

---

## 3. Architecture

```
┌─────────────────────────────────────────┐
│  PATCH COQUE (collé à plat, étanche)    │
│                                         │
│  BMI323 (IMU) ──I2C──┐                  │
│  BMP390 (baro) ──I2C─┤                  │
│  SHT40 (T/H) ──I2C───┤                  │
│                       ▼                  │
│              nRF52840 (Cortex-M4)        │
│                       │                  │
│                       ▼                  │
│              W25Q64 flash (64 Mo)        │
│                       │                  │
│                       ▼                  │
│              LiPo 300-500 mAh + USB-C    │
└─────────────────────────────────────────┘
         │
         │ post-course : USB ou NFC
         ▼
   PC / téléphone (récupération)
         │
         ▼
   DataR0w (import + analyse)
```

- **En course** : le patch enregistre tout en local. Aucune radio. Aucun téléphone.
- **Hors course** : récupération des données par USB (câble) ou NFC (téléphone à proximité). Le téléphone importe le fichier et le pousse dans Supabase comme une séance normale.
- **Pas de BLE en course** : interdit FFA. Le BLE du nRF52840 est réservé à la récupération post-course (mode « download ») ou à un usage hors compétition.

---

## 4. Format de stockage (flash)

Fichier binaire, une ligne par mesure (10 Hz) :

```
Offset 0  : t_ms        uint32  timestamp ms (epoch)
Offset 4  : gite_deg    int16   gîte ×100 (signe bâbord-)
Offset 6  : pitch_deg   int16   pitch ×100
Offset 8  : p_hpa       uint16  pression ×10 (hPa)
Offset 10 : alt_baro_cm int16   altitude barométrique (cm)
Offset 12 : temp_c_x100 int16   température ×100 (°C)
Offset 14 : hr_pct      uint8   humidité (%)
Offset 15 : flags       uint8   bit0=imu_valid, bit1=baro_valid, bit2=th_valid
```

24 octets/ligne × 10 Hz × 6 h = ~5.2 Mo. Avec en-tête (32 octets) : ~5.2 Mo. **64 Mo de flash = ~12 jours de régate.** Confortable.

Alternative CSV texte (plus lisible, ~40 octets/ligne) : ~10 Mo pour 6 h. Toujours dans les 64 Mo.

---

## 5. Validation sur le banc AvSim (avant prototype)

1. **Jeu de séances réelles** : QEPSSL + GT9JDK + GCZEKF (déjà en Storage) + nouvelles sorties.
2. **Algo de référence gîte** : IMU téléphone tareé (baseline actuelle).
3. **Critères de validation** :
   - Gîte : écart < 2° vs IMU téléphone tareé en régime stable.
   - Pitch : écart < 2°.
   - Pression : écart < 1 hPa vs station météo de référence.
   - Température : écart < 1 °C.
   - Humidité : écart < 5 % RH.
4. **Rapport** : `docs/RAPPORT-VALIDATION-PATCH-COQUE.md` avec courbes et chiffres.

---

## 6. Lots de build (ordre)

| Lot | Contenu | Commit |
|---|---|---|
| **P1** | Firmware nRF52840 : lecture I2C BMI323 + BMP390 + SHT40, écriture flash W25Q64, pas de BLE. Tests unitaires parseur. | `feat(patch): nrf52840 firmware v0.1 coque` |
| **P2** | App DataR0w : import fichier patch (USB/NFC) → session_meta + samples. | `feat(datar0w): patch coque import` |
| **P3** | Validation banc AvSim + rapport. | `docs: rapport validation patch coque` |
| **P4** | Mécanique : boîtier résine, potting, fixation VHB. Prototype 1. | `feat(patch): prototype mécanique v0.1` |
| **P5** | R&D girouette (voir §7). | `docs: cadrage R&D girouette` |
| **P6** | Sync cloud : données patch dans Supabase. | `feat(datar0w): patch coque sync cloud` |

**P1 et P2 = MVP utile.** P3 = validation. P4–P6 = produit complet.

---

## 7. R&D girouette (ouvert, hors scope immédiat)

Objectif : mesurer le vent (direction + vitesse) sans mât ni câblage, de façon collable/patchable.

Pistes à explorer :

1. **Pression différentielle** : 2 ports baro (BMP390 ×2) orientés face au vent et sous le vent. ΔP → vitesse. Problème : bruit, calibration, sensibilité à l'orientation du bateau.
2. **Accéléromètre du vent** : un petit hélice-girouette sur pivot à faible frottement, avec un accéléromètre qui mesure la rotation. Complexe mécaniquement.
3. **Estimation par gîte + vitesse** : le vent se déduit de la gîte et de la vitesse du bateau (modèle AvSim). Pas de capteur supplémentaire, mais indirect.
4. **Anémomètre à fils chaud** : consommation élevée, fragile.

**Recommandation** : commencer par la piste 3 (estimation AvSim, zéro matériel) en parallèle de la piste 1 (pression différentielle, 2 BMP390). Si la piste 1 donne un signal exploitable sur banc, on l'intègre au patch v0.2.

---

## 8. Propeller (hors scope, à rouvrir)

Un hélice sous la coque donnerait la vitesse eau (précise, indépendante du vent). Mais :

- Percement de la coque = invasif, interdit sur bateaux de location/club.
- Drag supplémentaire.
- Maintenance (algues, débris).

**Décision** : hors scope. Si un jour besoin de vitesse eau précise, on étudiera un hélice amovible à clip (pas de percement permanent).

---

## 9. Hors scope (volontaire)

- Solutions marché (NK, BioRow, SpeedCoach) — décision P1.
- GPS dans le patch (décision P2).
- Vent mécanique (décision P3, R&D §7).
- Propeller (décision P4).
- BLE en course (interdit FFA).
- Sync session_meta, Google OAuth, Stitch, #50, secrets.

---

## 10. Prompt Cursor (à coller, lot P1 d'abord)

```
Patch coque autonome FFA — lot P1 (firmware, aucun écran).
Lis docs/CADRAGE-PATCH-COQUE-AUTONOME.md, docs/CADRAGE-STROKE-SENSOR-DIY.md,
docs/CONVENTION-BABORD-TRIBORD.md.
Ne pas toucher AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets.
compileSdk 37, NDK 30.0.16248370. Pas de sdkmanager. Pas de windows/.

1) Repo séparé AvSim-patch ou dossier firmware/patch/ :
   - nRF52840 : lecture I2C BMI323 (gîte/pitch) + BMP390 (pression/altitude)
     + SHT40 (temp/humidité) à 10 Hz.
   - Écriture flash W25Q64 (format §4 : 16 octets/ligne).
   - Pas de BLE en mode course. Mode « download » USB/NFC séparé.
   - Alim LiPo 300-500 mAh, gestion charge USB-C.
2) Tests unitaires : parseur format flash, seuils, gestion pile faible.
3) flutter analyze clean (si code Dart). Tests verts.

Commit : feat(patch): nrf52840 firmware v0.1 coque
Stop si analyze casse. Pas de PR fourre-tout.
```

---

## 11. À discuter avant de coder

1. **Fréquence d'échantillonnage** : 10 Hz suffit-il pour la gîte (oui pour le régime, non pour les transitoires) ? → Recommandation : 10 Hz régime + 50 Hz si gîte > seuil.
2. **Format binaire vs CSV** : binaire = compact, CSV = lisible. → Recommandation : binaire en course, export CSV à la récupération.
3. **Fixation** : VHB seul ou VHB + vis ? → Recommandation : VHB + 2 vis de secours en diagonale.
4. **Multi-patch** : 1 patch par bateau suffit (gîte = coque) ? → Oui pour le gîte. Un 2e patch sur l'autre flanc donnerait le roulis différentiel (utile pour détecter un déséquilibre).

---

*Fin du cadrage patch coque autonome. Rien n'est codé tant que P1 n'est pas lancé.*
