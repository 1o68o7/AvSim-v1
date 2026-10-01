# Patch inventaire Bassin — 1er octobre 2026

> **Note** : le message utilisateur « Patch les points suivants : # Audit UX / UI / fonctionnel — 1er octobre 2026 » n’incluait **que le titre** (corps d’audit absent du transcript).  
> Patches appliqués = notes honnêteté + manques de [`DA-INVENTAIRE-BASSIN.md`](./DA-INVENTAIRE-BASSIN.md).  
> Si un audit complet existe ailleurs, le re-coller pour un second passage.

Projet principal : `1254927388471488287`  
Projet satellite manques : `1929126081667026582`  
DS Bassin : `assets/8677461250639537695`

## Patches honnêteté (edit Stitch → nouveaux screen ids)

| Id | Problème | Action | Screen id canonique |
|---|---|---|---|
| DR-32 | « balises UDP » / Recherche auto | Retiré | `da5e66b230654e7a921828347d44d124` |
| DR-20 affecté | « Capteurs prêts » | Retiré | `dbf9866bdde5475288f73a63e39e2c33` |
| DR-21 affecté | « Capteurs prêts (8/8) » | Retiré | `7061c3b0bb3d4bf5aaca350802f8152d` |
| DR-41 | Capteurs bassin inventés (T°/vent) | Retiré | `ec1f6b8b285748a2b66e1417dababde6` |

Anciens ids restent dans le projet Stitch mais **ne plus référencer**.

## Nouvelles planches (session patch)

### Projet principal

| Id | Screen id |
|---|---|
| DR-41 | `ec1f6b8b285748a2b66e1417dababde6` |
| DR-43 | `5d55059a685946deac7f837fa4df4443` |
| DR-44 | `3fa94b873da64cad86e0ae848357977d` |

### Projet satellite `1929126081667026582`

| Id | Screen id |
|---|---|
| DR-45 | `a522f419c674401ba06a8c48b2f62a0a` |
| DR-56 | `18bb422bcac44fe190d2a0ba7782f6f8` |
| DR-71 | `84e722e1c5d24eca9113506ea649a4bc` |
| DR-72 | `198b0c7b70f24524a4a488273b45cf80` |
| DR-73 | `40c99464a9d441edbebb18e0f7163610` |
| DR-74 | `95b165f84cc944a79f3ce48e145e751e` |
| DR-80 | `d05ab7e24297470e90de2ee525588695` |
| DR-90 | `6ccef4bc1d2145d78ccec671ce711668` |

HTML + PNG : `/opt/cursor/artifacts/da-challenge/DR-{45,56,71,72,73,74,80,90}-B.*`

## Encore ouverts

États secondaires uniquement (DR-01 erreur nav, DR-02 remplie, DR-04×2, DR-12 local, DR-13, DR-20 loisir, DR-21 vide, DR-31 vide, DR-50×3, DR-51×2, DR-52 tribords, DR-53 sens inverse, DR-60 vide) — voir inventaire.

## Ops Stitch

- Sur le projet challenge, `list_screens` MCP → `{}` ; timeouts fréquents ; reprise via projet satellite + `GEMINI_3_8_FLASH` pour récupérer les screen ids.
- Thumbnails Google parfois « wireframe » ; le HTML téléchargé porte bien les tokens Bassin (`#0E1418` / `#3D9B8F`).
