# Brief OEM — Patch dorsal PPG (DataR0w)

> Document de sourcing hardware. À envoyer à Goodway Techs (Shenzhen).
> Contact : Vivienne Fung — info@goodwaytechs.com — WhatsApp +86 13710951311
> Site : https://www.goodwaytechs.com

---

## 1. Qui on est

**DataR0w** — application mobile d'aviron (Flutter, iOS/Android) qui mesure
gîte, vitesse, distance et cadence en temps réel pendant la séance.
On développe un **capteur cardiaque dorsal** dédié au rameur : patch
adhésif posé sur le sternum / haut du dos, qui remonte FC, SpO2 et
orientation (gyro) vers le téléphone via BLE.

Le téléphone ne mesure pas le cardio (pas de capteur SpO2/cardio fiable au
poignet en aviron). Le capteur dorsal est le chaînon manquant.

---

## 2. Ce qu'on veut fabriquer

Un **patch dorsal PPG** :

- Forme : rectangle arrondi **ou** flèche (à trancher avec vous), ~40–50 mm × 25–30 mm, épaisseur < 8 mm.
- Surface arrière : fenêtre optique plane qui plaque contre la peau (sternum / T5–T6).
- Fixation : adhésif médical jetable (type 3M Red Dot) **ou** support réutilisable avec gel — à proposer.
- Étanchéité : **IP67 minimum**, IP68 souhaité (sueur + projection d'eau en aviron).
- Poids cible : < 15 g hors adhésif.
- Batterie : LiPo 3,7 V, 100–200 mAh, recharge USB-C (idéalement connecteur magnétique pogo), autonomie ≥ 60 h en usage aviron.
- Radio : **BLE 5.x**, profil GATT standard Heart Rate (0x180D / 0x2A37) + SpO2 custom. **Pas d'ANT+ requis.**
- MCU : nRF52840 (ou équivalent) avec **firmware 100 % ouvert / SDK direct** — on doit pouvoir le modifier nous-mêmes (algo anti-mouvement, seuils, OTA).
- Capteurs : PPG (FC + SpO2, LED verte/rouge/IR), accéléro 6 axes (LSM6DS3 ou équiv.), température de peau. **Pas de GSR/sudation** pour cette version.
- Certifications : CE, FCC, RoHS. ISO 13485 / biocompatibilité peau = **à discuter** (grade sport/fitness acceptable pour le MVP, médical souhaitable plus tard).

---

## 3. Pourquoi Goodway

Votre offre correspond : OEM/ODM full-stack (ID design, PCB, firmware, moulage
TPU/silicone, assemblage, QC), SDK/protocole direct, MOQ à partir de 500,
prototypage ~30 jours, CE/FCC/RoHS. On a vu que vous faites des montres
« medical-grade » (S200) et des anneaux IP68 — le patch dorsal est un
form-factor différent mais dans votre scope (private mold, silicone/nylon,
capteurs HR/SpO2 custom).

**Question clé à vous poser :** pouvez-vous aussi **mouler le boîtier**
(TPU / silicone médical) autour de la carte, avec fenêtre optique, dans la
même chaîne que l'électronique ? On veut un seul fournisseur de bout en
bout, pas un EMS + un mouleur séparés.

---

## 4. Commande pilote — MOQ réduit (IMPORTANT)

On n'est **pas** en phase de production de masse. On veut d'abord **valider
le concept sur l'eau**.

> **Demande : 5 exemplaires** (minimum absolu pour tester 2 rameurs + 2
> rechanges + 1 destructif), idéalement jusqu'à 10 si le prix unitaire reste
> raisonnable.

On comprend que votre MOQ catalogue est à 500. On demande explicitement
si vous acceptez une **commande pilote / prototype** en petite quantité
(5–10 unités) pour un projet ODM naissant, comme indiqué dans vos FAQ
(« MOQs negotiable for new businesses or product tests »).

Si 5 est impossible, indiquez-nous le **minimum réel** et le prix unitaire
correspondant. On préfère payer plus cher l'unité pour valider avant
d'engager une vraie série.

---

## 5. Livrables attendus de votre côté

1. **Devis** pour 5 (ou 10) prototypes, avec détail : électronique, moulage,
   batterie, assemblage, QC, emballage, expédition vers la France.
2. **Délai** de prototypage (vous annoncez ~30 jours — à confirmer pour ce
   form-factor).
3. **Schéma / BOM** indicatif du prototype (MCU, capteur PPG, batterie).
4. **Confirmation** que le firmware/SDK sera livré en accès direct (pas de
   boîte noire) et que OTA + modification algo sont possibles.
5. **Options de forme** : rectangle vs flèche — croquis ou 3D rapide.
6. **Options d'adhésif** : jetable médical vs réutilisable gel.
7. **Certifications** disponibles pour 5 unités (CE/FCC/RoHS sur prototype
   ou sur série seulement ?).
8. **Conditions** pour passer ensuite en série (MOQ, prix, délai).

---

## 6. Ce qu'on apporte de notre côté

- Spécification fonctionnelle complète (ce doc + schémas PPG/BLE).
- App mobile Flutter déjà en prod qui consomme le profil GATT standard
  (on a déjà le parser 0x2A37, le chip live, le replay).
- Tests sur l'eau avec rameurs réels (clubs partenaires en France).
- Retour itératif sur le signal (anti-mouvement, faux battements).

---

## 7. Planning souhaité

| Étape | Cible |
|---|---|
| Réponse + devis pilote | 2 semaines |
| Validation devis + bon de commande | +1 semaine |
| Prototypes reçus (5–10) | +4–6 semaines |
| Tests app + rameurs | +2 semaines |
| Itération 2 (si besoin) | +3 semaines |
| Décision série | après tests eau |

---

## 8. Contact

**DataR0w** — projet aviron connecté  
Contact : [à compléter — ton email / téléphone]  
Pays : France  
Langue : français ou anglais (indifféremment)

---

*Document généré pour DataR0w. À envoyer tel quel ou adapté.*
