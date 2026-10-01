# Hardware — Capteurs externes DataR0w

> Source de vérité hardware : **ce répertoire uniquement**.
> Les briefs du 1er octobre 2026 prévalent sur les anciens `docs/CADRAGE-CAPTEUR-*`.

---

## Structure

```
docs/hardware/
├── README.md
├── ARCHIVE.md
├── firmware-stroke-sensor.md
├── bench-wearables.md
├── stroke-sensor/
└── hull-patch/
    ├── README.md
    └── water-speed.md
```

## Capteurs

| Capteur | Répertoire | Source de vérité | Statut |
|---|---|---|---|
| Stroke sensor | `stroke-sensor/` | briefs + [`firmware-stroke-sensor.md`](firmware-stroke-sensor.md) | Briefs validés 2026-10-01 |
| Ceinture FC | [`bench-wearables.md`](bench-wearables.md) | Coospo H9Z | Achat banc |
| Bracelet souple | [`bench-wearables.md`](bench-wearables.md) | J-Style 2208A | Achat banc |
| Patch coque | `hull-patch/` | [water-speed.md](hull-patch/water-speed.md) | Cadré : logger, loch, vent |

## Abandonné

- Brassard PPG.
- Patch dorsal.
- Sudation.

## Règles

1. Un capteur fabriqué = un sous-répertoire kebab-case.
2. Les briefs du 1er octobre 2026 prévalent pour le stroke sensor.
3. Les anciens cadrages sont dans `docs/hardware/archive/`.
4. La FC de référence du banc est la ceinture H9Z.
5. Le loch ne copie pas Coxmate ni NK. Principes publics seulement.
