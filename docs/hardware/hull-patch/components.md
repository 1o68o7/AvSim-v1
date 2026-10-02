# Patch coque — composants

> 1er octobre 2026. Un logger. Entraînement BLE, course muette.
> Le coup de rame reste mesuré par le stroke sensor. Ici, la cadence coque est un secours.

## Ce que le boîtier doit sortir

| Mesure | Source | Note |
|---|---|---|
| Vitesse fond, trace | GNSS sur le logger | Indispensable en course : le BLE est coupé, le téléphone ne peut pas écrire dans la mémoire du boîtier |
| Gîte, tangage | IMU | Roulis = gîte coque. Pas la gîte de rame (stroke sensor) |
| Coups / min | IMU, accélération longitudinale | Secours si les clips rame sont absents. Moins propre que le stroke sensor |
| Vitesse eau | Loch plus tard | Option rivière. Pas dans le premier PCB |
| Vent apparent | Anémomètre BLE | Entraînement seulement. Pas sur le PCB |
| Conditions | Baro + température / humidité | Utile, pas prioritaire |

## PCB logger

| Rôle | Composant | Pourquoi |
|---|---|---|
| Radio + MCU | nRF52840-QFAA, même famille que le stroke sensor | BLE à l'entraînement, radio éteinte en course, même chaîne de flash |
| GNSS | u-blox MAX-M10S + antenne céramique | GPS / Galileo / GLONASS, ~1,5 m, basse conso. Environ 15–20 € le module, 46 $ en breakout SparkFun |
| Gîte, tangage, cadence coque | BMI323 | Déjà retenu. I2C |
| Pression | BMP390 | Déjà retenu |
| Air | SHT40 | Déjà retenu |
| Mémoire course | Flash SPI 8–32 Mo (W25Q64 ou équivalent) | Séance sans téléphone |
| Alim | LiPo 200–400 mAh + USB-C + MCP73831 + NTC | Même logique que le stroke sensor. Le GNSS tire plus, d'où la capacité |
| Horloge | 32 kHz du nRF | Timestamps alignés GNSS |

Pas de deuxième radio. Pas de propulseur. Le loch, s'il arrive, entre en impulsions Hall sur une GPIO, pas en BLE.

## Anémomètre

Achat, pas une carte à router. Il ne fait que le vent.

- Référence : **Calypso CMI1022** (ou Mini AB CMI1061). Ultrason, sans pièce mobile, BLE 5.1, IPX8, 43 mm, filetage 1/4".
- Batterie intégrée, recharge Qi, environ 150 h de mesure. Pas de fil, pas d'alim externe.
- Prix constaté : environ 290 £ (CMI1022), 349 $ (Mini chez Vakaros).
- Entraînement seulement, petit mât. En course il reste au ponton.
- L'app lit le vent apparent. Le vent vrai se calcule avec la vitesse fond et le cap du logger. Le Calypso ne fait ni GPS, ni gîte, ni coups/min.

Pas d'équivalent chinois à fonctions égales (octobre 2026) :

- Alibaba CMI1037 (Mianyang Xiangshu) : revendeur, 436 $ / 2 pièces, origine Espagne. Plus cher que le détail.
- Sentec WS3032 (~140 $) et Rika RK120-03 (459–585 $) : ultrasons filaires RS485, pas de batterie poche, pas de BLE, pas de 1/4".
- ISO 9001 vendeur ≠ étalonnage vent.

## Ce qu'on ne met pas sur ce PCB

- SpO2, sueur, FC : ceinture H9Z et bracelet 2208A.
- Coup de rame principal : stroke sensor.
- Loch et mât : sondes à part.
