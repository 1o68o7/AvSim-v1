# Hardware — Documentation des capteurs externes DataR0w

> Organisation : un sous-répertoire par capteur, avec les briefs techniques, design et variantes dedans.
> Version : 1.0 — 1er octobre 2026

---

## Structure

```
docs/hardware/
├── README.md                 ← ce fichier
├── stroke-sensor/            ← capteur de coup d'aviron (clip sur la rame)
│   ├── brief.md              ← électronique (PCB, BOM, BLE, firmware)
│   ├── design-brief.md       ← mécanique (clip TPU, boîtier, étanchéité)
│   └── latex-clip-brief.md   ← variante clip latex (moule maison)
├── ppg-armband/              ← capteur PPG brassard (FC + SpO2)
├── dorsal-patch/             ← patch dorsal ouvert (PPG + IMU)
└── hull-patch/               ← patch coque autonome (IMU + baro + stockage local)
```

## Capteurs

| Capteur | Répertoire | Statut |
|---|---|---|
| Stroke sensor | `stroke-sensor/` | Briefs validés, fichiers de conception à produire |
| PPG brassard | `ppg-armband/` | À documenter |
| Patch dorsal | `dorsal-patch/` | À documenter |
| Patch coque | `hull-patch/` | À documenter |

## Règles

- Chaque capteur a son sous-répertoire, nommé en kebab-case
- Les briefs portent des noms génériques (`brief.md`, `design-brief.md`) pour rester cohérents entre capteurs
- Les variantes (ex : clip latex) ont un nom explicite
- Un README par sous-répertoire quand le capteur a plus de 2 documents

---

*Document généré le 1er octobre 2026.*