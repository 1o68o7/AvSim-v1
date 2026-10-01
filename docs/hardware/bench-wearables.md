# Banc wearables — ceinture ECG et bracelet souple

> Choix du 1er octobre 2026 pour le banc skiff. Pas des capteurs à fabriquer.
> La sueur est hors périmètre. Le patch dorsal et le brassard PPG ne sont pas le banc.

## Ceinture — référence FC

| | |
|---|---|
| Produit | **Coospo Realzone H9Z** |
| Rôle | FC ECG, intervalles, zone. Référence pour l'app (`0x180D`) |
| Radio | BLE 5.0 + ANT+ |
| Alim | Rechargeable, ~50 h, câble + dock |
| Étanchéité | IP67, pas pour la natation |
| Prix constaté | ~39–44 € détail |
| Fiche | https://www.alibaba.com/product-detail/Coospo-H9Z-ANT-Wireless-Fitness-Sensor_1601153279626.html |
| Fiche marque | https://www.coospo.com/products/h9z-chest-heart-rate-monitor |

Écartée pour le banc : sangle générique Alibaba `1601668666238` (protocole inconnu).

## Bracelet — confort rameur

| | |
|---|---|
| Produit | **J-Style 2208A** |
| Rôle | Bracelet souple sans écran. FC optique + SpO2 de tendance. Demandé par des rameurs de compétition |
| Radio | BLE, SDK annoncé (Android / iOS) |
| Étanchéité | IP67 / IP68 selon fiche |
| Prix échantillon | ~26–37 $ |
| Fiche | https://www.alibaba.com/product-introduction/J-Style-2208A-Screen-less-Heart_1600946862907.html |

Le SpO2 poignet en aviron est une tendance, pas une mesure médicale. La FC bracelet ne remplace pas la H9Z.

## Hors banc

- Sudation : pas nécessaire pour le MVP. Pas de référence retenue.
- Patch dorsal : remplacé, pour le banc, par la H9Z.
- Brassard PPG : abandonné.
