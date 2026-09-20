# Point P — Patch dorsal PPG (clip / adhésif) pour DataR0w

> Cadrage hardware. Suite du Point R (capteur maison). Objectif : un capteur PPG **clipable ou adhésif sur le dos** (sternum / haut du dos), BLE, pour FC + SpO2 tendance, pensé rameur. Sources de commande réelles pour lancer la prod.

---

## 1. Pourquoi le dos (et pas le bras)

- Le dos (sternum, T4–T6) est un site PPG **stable** : moins de flexion que le poignet, moins de bruit que le biceps en aviron.
- Études PPG : sternum / torse = signal comparable au poignet au repos, **meilleur en mouvement** (pas de flexion poignée).
- Le maillot d'aviron couvre déjà la zone → patch discret, pas de brassard qui gêne le coup.
- Limite : sueur + frottement du maillot → adhésif médical obligatoire (pas de scotch).

Sources placement :
- PPG sites review (sternum, back) : https://www.mdpi.com/1424-8220/20/21/6300
- Wearable PPG placement study : https://www.mdpi.com/1424-8220/21/17/5950

---

## 2. Deux voies de prod (à trancher)

### Voie A — OEM Chileaf CL837 (rapide, ~3–6 semaines)
Le Aviron Pulse = **CL837 rebrandé**. On commande le même module en OEM, on change le firmware BLE + le boîtier dorsal.

| Élément | Détail | Lien / contact |
|---|---|---|
| Module CL837 | 47×30×11 mm, 12,1 g, IP67, BLE 5.0 + ANT+, FC + SpO2, 60 h | Alibaba : https://www.alibaba.com/product-detail/Chileaf-Heart-Rate-Monitor-Armband-CL837_1601219436643.html (25 $/u, MOQ 2) |
| Fiche fabricant | Specs, OEM/ODM page | https://www.chileaf.com/cl837-led-indicator-blood-oxygen-real-heart-rate-monitor-2-product/ |
| OEM/ODM | Formulaire contact | https://www.chileaf.com/oem-odm/ |
| Contact direct | info@chileaf.com / +86 18033087219 / WhatsApp | https://www.chileaf.com/contact-us/ |
| FCC teardown | Photos internes (valident OEM) | https://fccid.io/2ASQ9-CL837/Internal-Photos/Internal-photos-5863437 |
| Manuel | https://manuals.plus/chileaf/cl837-dual-module-ant-and-bluetooth-heart-rate-monitor-manual |

**Avantage** : certifié IP67/CE/FCC déjà, on gagne le boîtier. **Inconvénient** : firmware fermé (pas de custom algo anti-mouvement), SpO2 approximatif.

### Voie B — Maison (MAX86141 + XIAO nRF52840) — recommandée pour DataR0w
Contrôle total du firmware, algo anti-mouvement, GATT standard. Plus long (8–12 semaines proto → prod).

| Composant | Ref commande | Prix unitaire | Stock / dispo FR | Lien |
|---|---|---|---|---|
| **PPG AFE** MAX86141ENP+T | Analog Devices | ~8,6 € (DigiKey FR) / ~10 $ (Mouser) | 2 225+ (DigiKey) / 7 475 (Mouser) | https://www.digikey.fr/fr/products/detail/analog-devices-inc-maxim-integrated/MAX86141ENP-T/7804058 · https://www.mouser.com/ProductDetail/Analog-Devices-Maxim-Integrated/MAX86141ENP%2bT |
| **MCU** XIAO nRF52840 (pré-soudé) | Seeed 102010631 | 12,50 € TTC (Gotronic) / ~21 € (Amazon.fr) | En stock FR | https://www.gotronic.fr/art-carte-xiao-nrf52840-soude-47616.htm · https://www.amazon.fr/-/en/Seeed-Studio-Sense-nRF52840-Built/dp/B09T94SZ8K |
| **IMU** LSM6DSOX (anti-mouvement) | ST / breakout | ~5–8 € | AliExpress / Mouser | (breakout Qwiic/SparkFun) |
| **LiPo** 150–300 mAh + chargeur TP4056 | Générique | ~3–5 € | AliExpress | — |
| **Adhésif médical** (patch dorsal) | 3M Red Dot 2268-5 ou équiv. sport | ~2 €/u (lot) | Medimaxx / CORE patches | https://mdmaxx.com/products/3m-2268-5-red-dot-gentle-ecg-monitoring-electrode-with-conductive-adhesive-and-lift-tab · https://corebodytemp.com/products/research-medical-grade-sports-adhesive-patches |
| **PCB custom** | JLCPCB / PCBWay | ~2–5 €/u (100 u) | — | — |
| **Boîtier dorsal** | Moulage ABS/PC (sous-traitance) ou 3D (proto) | 1–3 €/u moulé | — | — |

**BOM prod (100 u) : ~25–40 €/unité** hors outillage moulage.

Datasheet MAX86141 : https://www.analog.com/en/products/max86141.html
Eval board (optionnel, pour valider) : MAX86140EVSYS# ~166 € (RS France) : https://fr.rs-online.com/web/p/kits-de-developpement-pour-capteur/1914228

---

## 3. Placement & fixation (patch dorsal)

- **Site** : sternum (milieu) ou T5–T6 (haut du dos), zone peu musclée, bonne perfusion.
- **Patch jetable** : 3M Red Dot 2268-5 (gel conducteur, 2 jours) — OK pour tests, pas idéal sueur aviron.
- **Patch sport long wear** : CORE medical-grade (15/pack, 24–48 h, douche OK) — https://corebodytemp.com/products/research-medical-grade-sports-adhesive-patches
- **Support réutilisable** : boîtier dorsal avec fenêtre optique + gel médical interchangeable (type Vivalink eSkin, 7 jours, waterproof) — https://www.mddionline.com/wearable-medical-devices/vivalink-debuts-wearable-ecg-adhesive
- **Alternative clip** : clip souple type Polar Verity mais orienté dos (moins confortable, à éviter en compétition).

Règle : **jamais de scotch** — adhésif médical certifié (ISO 13485 / CE) obligatoire pour la sueur et le frottement maillot.

---

## 4. Intégration DataR0w

Identique au Point R : le téléphone **reçoit** via BLE.
- GATT `0x180D` Heart Rate → `hrBpm`
- Service SpO2 custom → `spo2Pct` (tendance)
- IMU → compensation mouvement **côté firmware** (pas app)
- Chip discret sur `/live`, champs jsonl, sync cloud (Point B)

`flutter_blue_plus` déjà dans le pubspec. Aucun changement d'app pour R1–R3.

---

## 5. Lots P (ordre de build)

| Lot | Contenu | Livrable |
|---|---|---|
| **P0** | Décision Voie A (OEM) vs Voie B (maison) + commande échantillons | 5–10 CL837 OU 10× MAX86141 + 5× XIAO |
| **P1** | Breadboard : XIAO + MAX86141, firmware BLE HRS, FC au repos | Proto fonctionnel |
| **P2** | IMU + algo anti-mouvement, test aviron réel (rameur) | FC stable en coup |
| **P3** | Boîtier dorsal 3D + patch adhésif médical, IP67, 12 g | Patch portable |
| **P4** | App : scan BLE, chip FC `/live`, jsonl, seuils | Minimal |
| **P5** | Sync cloud + affichage coach | Minimal |
| **P6** | Certif CE/FCC + moulage prod (100 u) | Produit vendable |

**P0 peut partir maintenant** — commande d'échantillons, pas de code.

---

## 6. Décisions à trancher

1. **Voie A (OEM CL837) ou Voie B (maison MAX86141)** ? Recommandation : B pour le contrôle algo, A si tu veux un proto en 3 semaines.
2. **Patch jetable vs support réutilisable** ? Jetable (3M/CORE) pour tests, réutilisable (Vivalink-like) pour prod.
3. **SpO2 inclus** ? Oui, labellisé « tendance », jamais clinique.
4. **Certif CE/FCC** ? Obligatoire avant commercialisation. Prévoir dès P3.
5. **ANT+ en plus de BLE** ? Utile (Garmin), mais BLE suffit pour DataR0w.

---

## 7. Prompt Cursor (P0 — commande échantillons, aucun code)

```
Point P0 — commande échantillons capteur dorsal (hors code).
Lis docs/CADRAGE-CAPTEUR-PATCH-DORSAL.md et docs/CADRAGE-CAPTEUR-MAISON-PPG-BLE.md.

Ne pas toucher apps/datar0w. C'est de la logistique hardware.

1) Si Voie A : commander 5× CL837 OEM via Alibaba (info@chileaf.com)
   - Demander : firmware source ou au moins GATT 0x180D exposé,
     possibilité de rebranding logo, MOQ prod 100 u, délai.
2) Si Voie B : commander
   - 10× MAX86141ENP+T (DigiKey FR : https://www.digikey.fr/fr/products/detail/analog-devices-inc-maxim-integrated/MAX86141ENP-T/7804058)
   - 5× XIAO nRF52840 pré-soudé (Gotronic : https://www.gotronic.fr/art-carte-xiao-nrf52840-soude-47616.htm)
   - 20× patchs adhésifs 3M Red Dot 2268-5 (mdmaxx.com)
   - 5× breakout LSM6DSOX
3) Créer hardware/sensor-p0/README.md : BOM, liens, dates commande, tracking.
4) Pas de code. Juste la logistique + un tableau de suivi.

Commit : chore(sensor): P0 commande échantillons MAX86141 + XIAO + patches
```

---

*Point P — hardware. Ne bloque aucun lot logiciel. Permet à terme un capteur dorsal maison, sans dépendre d'Aviron Pulse (indispo FR) ni Polar (cher, pas de SpO2, pas de patch dorsal).*
