# Prompt Cursor — validation stroke sensor sur le banc AvSim (lot S5)

> **Statut** : prompt prêt à coller. Lot S5 du cadrage `docs/CADRAGE-STROKE-SENSOR-DIY.md`.
> **Date** : 2026-09-30
> **Prérequis** : séances réelles en Storage (QEPSSL, GT9JDK, GCZEKF) + nouvelles sorties 1x/2x/4x/8+.

---

## Prompt

```
Stroke sensor validation — banc AvSim (lot S5).
Lis docs/CADRAGE-STROKE-SENSOR-DIY.md (§5 validation), docs/STATE.md
(physique AvSim), docs/CADRAGE-TELEMETRIE-TEL.md.
Repo : avsim/ (Python). Ne pas toucher apps/datar0w, firmware, secrets.

## Objectif
Valider l'algo de détection de coup AVANT de commander des prototypes.
Baseline : détection pic ax sur IMU téléphone (QEPSSL : ~48 spm, SNR 1.1,
CV intervalles 47 % — à battre).

## Lots (1 commit chacun)

V1 — Module avsim/stroke/stroke_detect.py :
   - detect_strokes(imu_jsonl, seuil_mg, refractaire_ms) → liste
     {t_ms, ax_peak, interval_ms}
   - Paramètres : SEUIL_MG (défaut 2000), REFRAC_MS (défaut 800)
   - Test : série ax synthétique (pics connus) → détection exacte.
   Commit : feat(avsim): stroke detection baseline from phone imu

V2 — Métriques : SNR (pic/bruit), CV intervalles, % coups manqués,
   % faux positifs. Comparaison 2 méthodes : pic ax brut vs ax filtré
   (passe-bas 5 Hz) vs ax - g (soustraction gravité).
   Test : QEPSSL réel → rapport chiffres.
   Commit : feat(avsim): stroke detection metrics + qepssl report

V3 — Balayage SEUIL_MG 1000–4000 (pas 250) : courbe erreurs vs seuil.
   Choix du minimum. Test : GT9JDK + GCZEKF réels.
   Commit : feat(avsim): seuil sweep + optimal selection

V4 — Fenêtre réfractaire adaptative : fonction de la cadence estimée
   (2 min régime). Test : 4x et 8+ (cadence plus haute, intervalles plus courts).
   Commit : feat(avsim): adaptive refractory window

V5 — Rapport docs/RAPPORT-VALIDATION-STROKE-SENSOR.md :
   - Courbes SNR/CV/erreurs par classe (1x/2x/4x/8+)
   - Seuil optimal + réfractaire optimal
   - Critères S5 du cadrage : < 2 spm vs référence, < 1 % manqués,
     < 1 % faux positifs, gîte < 2°
   - Si critères non atteints : recommandations (montage capteur, filtre)
   Commit : docs: stroke sensor validation report

## Hors scope

- firmware nRF52840 (autre prompt)
- apps/datar0w (autre lots)
- Commande PCB / prototypes
- Secrets, AvSim UI Analyste

## Git

Branche feat/stroke-validation-banc depuis origin/main.
PR : feat(avsim): stroke detection validation on real sessions
Hors draft si tests verts.
```

---

## Notes

- La validation utilise les **séances déjà en Storage** (pas besoin de nouvelles sorties pour V1–V3).
- V4 nécessite des séances 4x/8+ — à faire si le club en a.
- Le rapport V5 est la **porte d'entrée** du lot firmware S4 : on ne flashe rien tant que les critères ne sont pas atteints.
