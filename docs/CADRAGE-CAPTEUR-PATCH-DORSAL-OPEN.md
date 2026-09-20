# Cadrage — Capteur patch dorsal OPEN-FIRMWARE (DataR0w)

> Complète `docs/CADRAGE-CAPTEUR-PATCH-DORSAL.md` (commit 99e4f1c5).
> Objectif : **firmware 100 % modifiable par nous**, pas de boîte noire OEM, production en grande série à bas coût, stock pré-achat possible.
> Date : 2026-09-20.

---

## 1. Constat marché (sourcé)

| Produit / module | Firmware | SDK ouvert ? | MOQ prod | Prix unité | Remarque |
|---|---|---|---|---|---|
| **Chileaf CL837** (Aviron Pulse OEM) | Fermé, protocole propriétaire Chileaf SDK v0.6 | Non. Repo tiers `paoloartasensi/cl837` = reverse-engineering Flutter, pas le code source usine | 2 (sample) | ~25 $ | Boîte noire. À écarter pour notre besoin. |
| **MAX86141 + XIAO nRF52840** (voie maison) | **100 % nôtre** (nRF Connect SDK / Zephyr, libs Arduino MIT) | Oui, total | 1 (composants) | ~25–40 € BOM | Choix retenu. |
| **Goodway Techs** (Shenzhen) OEM/ODM smart band | Personnalisable en profondeur, SDK + protocole direct fournis | Oui (SDK/API pour ODM) | 500–1000 | à chiffrer | Alternative si on veut externaliser le moulage. |
| **Staranb** (Shenzhen) OEM smart ring/band nRF52832 | "open source code development" annoncé | À vérifier contrat | 1 (sample) | à chiffrer | À qualifier. |

**Décision figée** : on part sur la **voie maison MAX86141 + nRF52840**, firmware open de A à Z. Le CL837 reste un fallback hardware si le moulage maison coûte trop cher, mais **jamais** comme base firmware.

---

## 2. Stack retenu (open, reproductible)

- **MCU** : Seeed XIAO nRF52840 (UF2 bootloader, SWD) — https://wiki.seeedstudio.com/XIAO_BLE/ — 12,50 € TTC chez Gotronic.
- **AFE PPG** : MAX86141ENP+T (Analog Devices) — 8,62 € DigiKey FR, 2 225 en stock. LED verte + rouge + IR, 1–3 photodiodes, FIFO 128, anti-mouvement hardware.
- **Firmware** : nRF Connect SDK (Zephyr) **ou** Arduino core Adafruit nRF52 (MIT). Libs MAX86141 open : `MakerLabLPI/Max86141`, `bridgepcb/MAX86141`, `joshbrew/MAX86141_Arduino` (toutes MIT/Apache).
- **Profil BLE** : GATT standard `0x180D` Heart Rate + custom char SpO2/temp (on contrôle le protocole, pas de reverse-engineering).
- **Référence open complète** : `movuino/OpenHealthBandFirmware` (MAX86141 + nRF52 + BLE, MIT) — base de code à forker.
- **Référence plateforme** : `Protocentral/healthypi-move` (MAX86141 + nRF5340, Zephyr, open hardware+software) — Crowd Supply, preuve que le stack tourne en prod.

---

## 3. BOM prod (estimée, hors moulage)

| Poste | Réf | Qté | Prix unité | Total |
|---|---|---|---|---|
| MCU | XIAO nRF52840 | 1 | 12,50 € | 12,50 |
| AFE PPG | MAX86141ENP+T | 1 | 8,62 € | 8,62 |
| LED verte/rouge/IR + PD | intégré MAX86141 | 1 | inclus | 0 |
| Accéléro (anti-mouvement) | LIS2DH12 ou BMA400 | 1 | ~1,50 € | 1,50 |
| Batterie LiPo | 3,7 V 150–200 mAh | 1 | ~2,00 € | 2,00 |
| Chargeur | MCP73831 | 1 | ~0,80 € | 0,80 |
| PCB flex + composants passifs | custom | 1 | ~3,00 € | 3,00 |
| Adhésif médical | 3M Red Dot 2268-5 ou CORE | 1 | ~0,50 € | 0,50 |
| **Total BOM** | | | | **~29 €** |

Avec moulage silicone + QC + logistique : **35–45 €** l'unité en série 500+.

---

## 4. Fournisseurs à contacter (SDK ouvert exigé)

1. **Goodway Techs** (Shenzhen) — OEM/ODM smart band, SDK + protocole direct, MOQ 500–1000, CE/FCC/RoHS. Contact : Vivienne Fung, +86 13710951311, info@goodwaytechs.com, WhatsApp +86 13710951311. https://www.goodwaytechs.com/smart-bands1.html
2. **Staranb** (Shenzhen) — OEM nRF52832, "open source code development" annoncé. À qualifier par contrat. https://staranb.en.made-in-china.com
3. **Composants directs** (si on fait le moulage nous-mêmes) :
   - MAX86141ENP+T : https://www.digikey.fr/en/products/detail/analog-devices-inc/MAX86141ENP-T/5984390
   - XIAO nRF52840 : https://www.gotronic.fr (ou Seeed officiel)
   - Adhésifs 3M Red Dot : https://www.3m.com/medical

**Critère non négociable dans le brief fournisseur** : *"full source code delivery, no black-box libraries, no licensing fees, OTA DFU, protocol spec written."*

---

## 5. Placement patch dorsal

- **Site 1** : sternum (milieu), sous le maillot. Signal fort, peu de mouvement relatif au torse.
- **Site 2** : T5–T6 (haut du dos), entre les omoplates. Bon compromis sueur/frottement.
- **Site 3** : paravertébral gauche, évite la colonne.
- Adhésif : gel médical 3M Red Dot 2268-5 (réutilisable 3–5 jours) ou patch jetable hydrocolloïde. Tester la tenue sous sueur + flexion du dos en aviron.

---

## 6. Lots (ordre de build)

- **P0** — Commande échantillons : 5× MAX86141 + 5× XIAO nRF52840 + adhésifs. Breadboard, firmware de base (HR GATT), validation signal sur le dos. *Aucune écriture code app.*
- **P1** — PCB flex custom + firmware complet (HR + SpO2 + temp + accéléro anti-mouvement), OTA, protocole documenté.
- **P2** — Moulage silicone + adhésif, tests étanchéité IP67, tests mouvement (rameur sur ergomètre).
- **P3** — Intégration Flutter : `ble_hr_client.dart` (GATT 0x180D + char SpO2), chip discret sur `/live`, champs `hrBpm`/`spo2Pct`/`skinTemp` dans jsonl.
- **P4** — Série 500+, QC, stock, packaging DataR0w.

---

## 7. Prompt Cursor (P0 — échantillons + breadboard, pas d'écran)

```
DataR0w — lot P0 capteur patch dorsal OPEN-FIRMWARE.
Lis docs/CADRAGE-CAPTEUR-PATCH-DORSAL.md et docs/CADRAGE-CAPTEUR-PATCH-DORSAL-OPEN.md.
Ne pas toucher AvSim. Ne pas revert compileSdk 37 / NDK 30.
Pas de sdkmanager. Pas de windows/.

## Objectif
Valider le hardware MAX86141 + XIAO nRF52840 sur breadboard,
firmware open (nRF Connect SDK ou Arduino Adafruit nRF52),
profil BLE GATT 0x180D + char SpO2 custom.
Aucun écran Flutter dans ce lot. Juste le prototype + un script Python
de lecture BLE pour valider le signal.

## À faire
1. Créer lib/sensors/ble_hr_client.dart (stub) : scan GATT 0x180D,
   parse HR Measurement, char SpO2 custom (UUID à définir dans le firmware).
2. Créer docs/HARDWARE-P0-BOM.md : liste composants + liens commande
   (DigiKey MAX86141, Gotronic XIAO, 3M Red Dot).
3. Créer firmware/ (dossier) : squelette PlatformIO ou nRF Connect SDK
   pour XIAO nRF52840 + MAX86141, profil HR GATT, LED verte blink = vie.
4. Script tools/ble_hr_sniff.py : se connecte au prototype, log HR + SpO2
   toutes les 1 s dans un CSV.
5. Test : brancher sur un volontaire, poser sur le sternum, vérifier
   que le signal HR est stable (pas de dropout > 2 s) en mouvement léger.

## Hors scope
Moulage, adhésif final, série, intégration /live complète, OTA.

## Vérifs
flutter analyze clean (stub seulement).
Script Python tourne sans erreur.
Signal HR visible dans le CSV.

Commit : feat(datar0w): P0 capteur patch dorsal — stub BLE + squelette firmware + BOM
```

---

## 8. Décisions figées

- **D1** : firmware 100 % open, aucun code propriétaire fournisseur. Exigence contractuelle.
- **D2** : stack MAX86141 + nRF52840 (pas CL837) pour le contrôle total.
- **D3** : placement dorsal (sternum ou T5–T6), adhésif médical 3M.
- **D4** : SpO2 inclus mais labellisé "approximatif en mouvement" ; FC = priorité absolue.
- **D5** : série 500+ dès P4, stock pré-achat autorisé.
- **D6** : pas de sudation (GSR) dans ce patch — hors scope, à ajouter plus tard si besoin.
