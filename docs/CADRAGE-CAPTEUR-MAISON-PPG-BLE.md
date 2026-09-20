# Point R — Capteur maison PPG BLE (FC + SpO2) pour DataR0w

> Cadrage exploratoire. Aucun code dans ce lot. Objectif : savoir si on peut fabriquer un capteur optique clipable sur le bras, compatible BLE, pour enrichir `/live` et le jsonl — sans dépendre d'un OEM (Aviron Pulse, Polar Verity Sense).

---

## 1. Constat marché (sourcé)

| Produit | Techno | Forme | Prix | Dispo FR | Limite aviron |
|---|---|---|---|---|---|
| **Polar Verity Sense** | PPG optique + accéléro + gyro | Clip 5 g, brassard bras | ~90 € | Oui | SpO2 absent ; SDK officiel (PPG 55 Hz, ACC 52 Hz) |
| **Aviron Pulse** | PPG + SpO2 (FCC : module OEM Shenzhen Chileaf CL837) | Clip 12,1 g, IP67 | 79–89 $ | Non (US only) | SpO2 approximatif en mouvement |
| **Coros / Scosche / Cardiosport** | PPG optique | Brassard / clip | 40–80 € | Oui | SpO2 rare ou absent |

Sources :
- Aviron Pulse FCC ID `2ASJ3-AVIRONPULSE` (changement d'ID depuis Chileaf `2ASQ9-CL837`) : https://fcc.report/FCC-ID/2ASJ3-AVIRONPULSE
- Polar Verity Sense SDK : https://github.com/polarofficial/polar-ble-sdk (doc produit : https://github.com/polarofficial/polar-ble-sdk/blob/master/documentation/products/PolarVeritySense.md)
- Précision bras vs poignet (étude) : bras supérieur = MAPE 1,35 %, poignet bien pire — https://www.mdpi.com/1424-8220/26/1/176
- Verity Sense en aviron : 1–2 BPM d'écart vs sangle pectorale (DC Rainmaker / TechRadar).

**Conclusion marché** : le brassard optique sur le bras est le bon format. Le poignet est à proscrire en aviron (flexion poignée = artefacts). Le SpO2 en continu pendant l'effort reste approximatif partout.

---

## 2. Techno à reproduire (ouverte)

Principe : **PPG** (photoplethysmographie). LED verte (FC) + rouge/IR (SpO2) → photodétecteur → MCU calcule BPM et SpO2 → BLE GATT standard `0x180D` (Heart Rate) + service SpO2 custom.

### 2.1 Stack recommandé (prototype → produit)

| Couche | Choix prototype | Choix produit |
|---|---|---|
| MCU | Seeed XIAO nRF52840 (BLE 5, 3,8 µA sleep) | nRF52840 custom PCB |
| PPG AFE | MAX30102 (breakout ~3 $) | **MAX86141** (19-bit ADC, compensation mouvement, >89 dB dynamique) |
| IMU (anti-mouvement) | BME280 / LIS3DH | LSM6DSOX 6-axes |
| Alim | LiPo 100–220 mAh + TP4056 | LiPo 3,7 V + charge USB-C |
| Boîtier | Impression 3D + fenêtre optique | Moulé ABS/PC, IP67, 12 g |
| Firmware | nRF Connect SDK / Zephyr ou ArduinoBLE | nRF5 SDK + SoftDevice S140 |

Le MAX86141 est le vrai saut de qualité vs MAX30102 : ADC 19 bits, rejet lumière ambiante >70 dB, algos motion-compensated (Maxim MAX-HEALTH-BAND). C'est ce que visent les produits pros.

### 2.2 Sources hardware / firmware

- MAX30102 + nRF52840 (sommeil/posture) : https://forum.seeedstudio.com/t/xiao-nrf52840-mbed-1-central-2-peripherals-project-sleeping-posture-heart-rate-pulse-oximetry-monitor/269923
- MAX30102 + ESP32 BLE NimBLE PLX : https://github.com/JoshDumo/esp32-max30102-nimBLE-PLX
- MAX86141 lib Arduino (nRF52840 + ESP32) : https://github.com/MakerLabLPI/Max86141
- MAX86141 + IMU (Open Health Band) : https://github.com/movuino/OpenHealthBandFirmware
- MAX86141 datasheet : https://www.analog.com/en/products/max86141.html
- MAX30102 breakout : https://circuit.rocks/products/pulse-oximeter-heart-rate-sensor-breakout-max30102
- Principe PPG (TI) : https://www.ti.com.cn (app note PPG)
- Algorithme motion-compensated (Maxim, testé rowing) : https://www.mouser.com/pdfDocs/maxim-Intelligent-Healthcare-MAX32664-appnote.pdf
- Bague open-source nRF52840 + PPG 3 longueurs : https://github.com/thuhci/OpenRing

---

## 3. BOM indicative (prototype, ~25–40 €)

1. Seeed XIAO nRF52840 — 12 €
2. MAX30102 breakout (ou MAX86141 eval) — 3–15 €
3. LiPo 150 mAh + TP4056 — 4 €
4. Brassard / clip 3D — 2 €
5. Câbles, breadboard — 3 €

Total prototype < 40 €. Produit fini (PCB custom + moulage) : viser 15–25 € BOM.

---

## 4. Intégration DataR0w (Flutter)

Le téléphone ne mesure rien. Il **reçoit** via BLE :

- Service GATT `0x180D` Heart Rate → `hrBpm` (déjà prévu dans `docs/CADRAGE-CARDIO-BLE-RAMEUR.md`).
- Service SpO2 custom → `spo2Pct` (optionnel, labellisé « approximatif »).
- IMU du capteur → compensation mouvement côté firmware (pas côté app).

Côté app : `flutter_blue_plus` (déjà dispo) scanne, se connecte, souscrit. Chip discret sur `/live`. Champs optionnels dans le jsonl. Sync cloud (Point B) pour le coach.

---

## 5. Lots R (ordre de build)

| Lot | Contenu | Écrans |
|---|---|---|
| **R1** | Prototype breadboard : XIAO nRF52840 + MAX30102, firmware BLE HRS, lecture FC au repos | Aucun (test série) |
| **R2** | Port MAX86141 + IMU, algo anti-mouvement, test aviron réel (rameur) | Aucun |
| **R3** | Boîtier clip/brassard 3D, IP67, 12 g, batterie 8 h+ | Aucun |
| **R4** | App : scan BLE, chip FC sur `/live`, champs jsonl, seuils | Minimal |
| **R5** | Sync cloud + affichage coach (replay / live) | Minimal |

**R1 peut démarrer en parallèle de H1–H3 (architecture) et du Point C.** C'est un chantier hardware distinct, pas bloquant pour le logiciel.

---

## 6. Décisions à trancher

1. **PPG seul ou + IMU** ? IMU recommandé dès R2 (compensation mouvement aviron).
2. **SpO2 inclus** ? Oui mais labellisé « tendance », jamais clinique.
3. **Boîtier maison ou sous-traitance moulage** ? Maison (3D) pour R1–R3, moulage pour R5.
4. **Compatibilité ANT+** ? Utile (Garmin), mais BLE suffit pour DataR0w. À voir plus tard.
5. **Certif CE/FCC** ? Obligatoire avant commercialisation. Prévoir dès R3.

---

## 7. Prompt Cursor (R1 — prototype, aucun écran)

```
Point R1 — prototype capteur PPG BLE (hors app Flutter).
Lis docs/CADRAGE-CAPTEUR-MAISON-PPG-BLE.md et docs/CADRAGE-CARDIO-BLE-RAMEUR.md.

Ne pas toucher apps/datar0w (Flutter). C'est un dépôt hardware séparé
(ex. repo datar0w-sensor/ ou dossier hardware/).

Objectif : faire clignoter une LED verte MAX30102 sur XIAO nRF52840,
mesurer FC au repos, broadcaster via BLE GATT 0x180D.

1) Créer repo/dossier hardware/sensor-r1/
2) PlatformIO : board seeed_xiao_nrf52840, framework arduino
3) Driver MAX30102 (I2C) : lire IR + RED, calculer BPM simple (pic detection)
4) BLE peripheral : service 0x180D, char 0x2A37, notify 1 Hz
5) LED status : vert = connecté, bleu = mesure OK
6) README : BOM, câblage, flash, test avec nRF Connect (mobile)
7) Critère de sortie : FC lue au repos ±5 BPM vs doigt sur capteur commercial

Commit : feat(sensor): R1 prototype MAX30102 + nRF52840 BLE HRS
Stop si le prototype ne broadcaste pas.
```

---

*Point R — exploratoire. Ne bloque aucun lot logiciel (C/D/E/H). Permet à terme de ne plus dépendre d'Aviron Pulse (indispo FR) ni Polar (cher, pas de SpO2).*
