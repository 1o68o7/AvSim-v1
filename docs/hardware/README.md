# Hardware — Capteurs externes DataR0w

> Source de vérité hardware : **ce répertoire uniquement**.
> Les briefs du 1er octobre 2026 prévalent sur les anciens `docs/CADRAGE-CAPTEUR-*`.

---

## Structure

```
docs/hardware/
├── README.md
├── ARCHIVE.md
├── firmware-stroke-sensor.md   ← guideline build / flash / MAJ BLE
├── bench-wearables.md          ← ceinture H9Z + bracelet 2208A (banc)
├── stroke-sensor/
├── dorsal-patch/
└── hull-patch/
```

## Capteurs

| Capteur | Répertoire | Source de vérité | Statut |
|---|---|---|---|
| Stroke sensor | `stroke-sensor/` | briefs + [`firmware-stroke-sensor.md`](firmware-stroke-sensor.md) | Briefs validés 2026-10-01 |
| Ceinture FC | [`bench-wearables.md`](bench-wearables.md) | Coospo H9Z | Achetée pour le banc, pas fabriquée |
| Bracelet souple | [`bench-wearables.md`](bench-wearables.md) | J-Style 2208A | Banc confort. FC optique + SpO2 tendance |
| Patch dorsal | `dorsal-patch/` | README | Remplacé au banc par la H9Z |
| Patch coque | `hull-patch/` | README | À documenter |

## Abandonné

- **Brassard PPG** : retiré le 1er octobre 2026.
- **Sudation** : hors MVP. Pas de référence.

## Règles

1. Un capteur fabriqué = un sous-répertoire kebab-case.
2. Les briefs du 1er octobre 2026 **prévalent** pour le stroke sensor.
3. Les anciens cadrages sont dans `docs/hardware/archive/`.
4. Pas de doublon à la racine de `docs/`.
5. La FC de référence du banc est la ceinture H9Z, pas un brassard ni le patch dorsal.
