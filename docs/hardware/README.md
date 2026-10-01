# Hardware — Capteurs externes DataR0w

> Source de vérité hardware : **ce répertoire uniquement**.
> Les briefs du 1er octobre 2026 prévalent sur les anciens `docs/CADRAGE-CAPTEUR-*`.

---

## Structure

```
docs/hardware/
├── README.md
├── ARCHIVE.md                 ← cadrages historiques (dépréciés)
├── firmware-stroke-sensor.md   ← guideline build / flash / MAJ BLE
├── stroke-sensor/             ← capteur de coup (clip rame)
│   ├── README.md
│   ├── brief.md                ← électronique (prévaut)
│   ├── design-brief.md         ← mécanique TPU (prévaut)
│   └── latex-clip-brief.md     ← variante latex (prévaut)
├── ppg-armband/
├── dorsal-patch/
└── hull-patch/
```

## Capteurs

| Capteur | Répertoire | Source de vérité | Statut |
|---|---|---|---|
| Stroke sensor | `stroke-sensor/` | `brief.md` + `design-brief.md` + `latex-clip-brief.md` + [`firmware-stroke-sensor.md`](firmware-stroke-sensor.md) | Briefs validés 2026-10-01 |
| PPG brassard | `ppg-armband/` | README + archive cadrage PPG | À documenter |
| Patch dorsal | `dorsal-patch/` | README + archive cadrages patch | À documenter |
| Patch coque | `hull-patch/` | README + archive cadrage coque | À documenter |

## Règles

1. Un capteur = un sous-répertoire kebab-case.
2. Les briefs du 1er octobre 2026 **prévalent** (LiPo + USB-C, PCB 25×30, protection NTC, clip latex/TPU).
3. Les anciens fichiers `docs/CADRAGE-STROKE-SENSOR-DIY.md`, `docs/CADRAGE-CAPTEUR-*`, `docs/CADRAGE-PATCH-COQUE-AUTONOME.md` et `docs/BRIEF-GOODWAY-PATCH-DORSAL.md` sont déplacés dans `docs/hardware/archive/` — historique seulement.
4. Pas de doublon à la racine de `docs/` ni de `docs/hardware/`.
