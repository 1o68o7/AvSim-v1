# Stroke Sensor — Brief technique v1

> Document de conception du premier capteur externe DataR0w : le stroke sensor.
> Version : 1.0 — 1er octobre 2026
> Statut : brief validé, fichiers de conception à produire (KiCad)

---

## 1. Objectif

Capteur de coup d'aviron clipé sur le manche de la rame. Il mesure le gîte et l'accélération du coup et les transmet en BLE au téléphone (hub DataR0w). La position, vitesse et distance viennent du GNSS du téléphone — le capteur n'a pas de GPS.

C'est le premier des quatre capteurs externes à fabriquer (stroke sensor, PPG brassard, patch dorsal, patch coque autonome).

## 2. Architecture matérielle

### 2.1 PCB

| Paramètre | Valeur |
|---|---|
| Dimensions | 25 × 30 mm (voir §5.2 pour le support batterie) |
| Couches | 2 |
| Matériau | FR4, 1,6 mm |
| Finition | HASL sans plomb |
| Références | 13 |
| Composants | 17 au total |

### 2.2 Bill of Materials

| Réf | Composant | Package | Notes |
|---|---|---|---|
| U1 | nRF52840-QFAA | QFN48 (6×6 mm, 48 pads, pitch 400 µm) | Cerveau BLE. Accepte 1,7–3,6 V directement — pas de boost nécessaire |
| U2 | BMI323 | LGA14 (2,5×3 mm) | Accéléro + gyro. I2C jusqu'à 1 MHz. 790 µA en haute performance |
| U3 | MCP73831T | SOT-23 | Chargeur LiPo USB-C |
| U4 | DW01A + MOSFET | SOT-23 | Protection LiPo (overcharge/overdischarge/short) |
| R_NTC | NTC 10 kΩ | 0402 | Thermistor collé sur la LiPo, branché sur la broche THERM du MCP73831 — coupe la charge sous 0 °C |
| J1 | Réceptacle USB-C SMD | — | Recharge |
| BT1 | Support LiPo | — | Connecteur JST 1,25 mm |
| L1, C1, C2 | Antenne chip 2,4 GHz + circuit d'adaptation | — | Johanson 2450AT18A100E (3,2×1,6 mm) + 2 inductances + 1 condensateur. Zone de garde au sol obligatoire autour |
| LED1 | LED verte | 0402 | État BLE |
| LED2 | LED rouge | 0402 | État charge |
| SW1 | Bouton tactile | — | Reset / appairage |
| C3–C6 | Condensateurs découplage | 0402 | Selon datasheets nRF52840 et BMI323 |
| J2 | Pads SWD | — | Programmation et debug |

**Composants supprimés par rapport à la v0** : TPS61099 (boost inutile — le nRF52840 accepte la LiPo 3,7 V directement), inductances et condensateurs associés.

### 2.3 Alimentation

- **Batterie** : LiPo 3,7 V, 40–60 mAh, format 4×20×2,5 mm
- **Autonomie** : ~12 h en actif continu (IMU 50 Hz + BLE 10 Hz), plusieurs semaines en veille profonde (nRF52840 : 0,4 µA en deep sleep)
- **Recharge** : USB-C, ~1 h pour une charge complète
- **Protection thermique** : double couche
  1. NTC sur la broche THERM du MCP73831 → coupe matérielle de la charge sous 0 °C
  2. Firmware : le nRF52840 lit son capteur de température interne et refuse la charge sous 0 °C (message sur l'app)
  3. Avertissement dans le manuel : « Ne rechargez pas sous 0 °C » (pratique standard drones / VAE)

### 2.4 Mécanique

- Clip en **TPU** imprimé 3D (FabLab Cap Sciences, Bordeaux) — pas de moule industriel à ce stade
- Profil en U qui épouse le manche de la rame, nervures internes pour absorber les vibrations
- Le port USB-C ajoute ~3 mm de hauteur → à intégrer dans le dessin du clip
- Étanchéité : joint torique + potting résine époxy pour le test skiff ; surmoulage LSR pour la production

## 3. Protocole BLE

| Élément | Valeur |
|---|---|
| Service | 0xA000 |
| Caractéristique stroke | 0xA001 — 12 octets : timestamp, gîte, accélération X/Y/Z |
| Caractéristique config | 0xA002 — réglage de l'intervalle d'envoi |
| Cadence IMU | 50 Hz |
| Cadence envoi BLE | 10 Hz |

Le téléphone (app DataR0w) fait le GNSS, le calcul de distance et la synchronisation multi-capteurs.

## 4. Firmware

- Langage : C sur SDK **nRF Connect** avec Zephyr
- Boucle : lecture I2C du BMI323 à 50 Hz → filtrage du gîte (tau 0,32 s) → envoi BLE à 10 Hz
- Gestion de la charge : lecture NTC + capteur interne, refus sous 0 °C
- Appairage : bouton SW1

## 5. Fabrication

### 5.1 PCBA

- Fournisseur : **EMS Proto**, Technopole Montesquieu, Pessac (Gironde) — seul service d'assemblage automatisé dédié prototypes en Gironde
- Devis en ligne gratuit, 48–72 h
- Coût estimé : 50–80 € (setup + 1 pièce) pour le premier run

### 5.2 Point d'attention PCB

Le support CR2032 Keystone 1058 (28,4×16 mm) dépasse la largeur de 20 mm → d'où le passage à 25×30 mm. Avec la LiPo (4×20 mm), 25 mm de largeur suffisent.

### 5.3 Clip

- Modélisation : **FreeCAD** (gratuit), profil en U + nervures
- Impression : FabLab Cap Sciences (quai de Bacalan, Bordeaux) — ouvert jeudi/vendredi/samedi 14h–18h
- Alternative : B3D Makers (Arts et Métiers, Talence) pour l'impression résine à coût réduit

### 5.4 Coût total estimé (1er capteur)

| Poste | Coût |
|---|---|
| PCB (5 pièces) | 15 € |
| BOM | 7 € |
| PCBA EMS Proto | 50–80 € |
| Clip TPU (matière) | 2–5 € |
| **Total** | **~75–110 €** |

## 6. Fichiers à produire

- [ ] Schéma KiCad
- [ ] Routage PCB KiCad (Gerber, BOM, positions de placement)
- [ ] Modèle FreeCAD du clip (STL)
- [ ] Firmware Zephyr (repo séparé : `datar0w-firmware`)

## 7. Prochaines étapes

1. Dessiner le schéma et le routage dans KiCad à partir de ce brief
2. Commander le PCBA chez EMS Proto
3. Imprimer le clip au FabLab
4. Test fonctionnel en eau réelle sur skiff
5. Si OK → version produit : LiPo + USB-C validés, passage au moule silicone bridge (3–5 k€)

---

*Document généré le 1er octobre 2026. À mettre à jour à chaque itération de conception.*