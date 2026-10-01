# Stroke Sensor

> Capteur de coup d'aviron clipé sur le manche de la rame. Mesure le gîte et l'accélération du coup, transmet en BLE au téléphone (hub DataR0w). La position, vitesse et distance viennent du GNSS du téléphone.
>
> Version : 1.0 — 1er octobre 2026

---

## Documents

| Fichier | Contenu |
|---|---|
| [brief.md](brief.md) | Électronique : PCB 25×30 mm, BOM, alimentation LiPo USB-C, protection thermique, protocole BLE, firmware Zephyr, fabrication EMS Proto |
| [design-brief.md](design-brief.md) | Mécanique : clip TPU profil en U, boîtier monobloc, étanchéité potting/LSR, contraintes fonctionnelles |
| [latex-clip-brief.md](latex-clip-brief.md) | Variante : clip latex moulé maison (cire perdue, plâtre), pour le prototype skiff |

## Statut

- [x] Brief technique validé
- [x] Brief design validé
- [x] Brief clip latex validé
- [ ] Schéma + routage KiCad
- [ ] Modèle FreeCAD du clip
- [ ] Firmware Zephyr (repo `datar0w-firmware`)
- [ ] PCBA EMS Proto
- [ ] Test skiff (2 capteurs, 1 rameur)

## Coût estimé (1er capteur)

~75–110 € (PCB 15 € + BOM 7 € + PCBA 50–80 € + clip 2–5 €)

## Prochaines étapes

1. Dessiner le schéma et le routage dans KiCad
2. Commander le PCBA chez EMS Proto (Technopole Montesquieu, Pessac)
3. Imprimer le clip au FabLab Cap Sciences
4. Test fonctionnel en eau réelle sur skiff

---

*Document généré le 1er octobre 2026.*