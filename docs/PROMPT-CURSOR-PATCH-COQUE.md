# Prompt Cursor — patch coque autonome FFA

> À coller dans Cursor, **lot P1 d'abord**. Branche `feat/patch-coque` depuis `origin/main`.
> Cadrage : docs/CADRAGE-PATCH-COQUE-AUTONOME.md

---

## Lot P1 — firmware nRF52840 (repo séparé ou dossier firmware/patch/)

```
Patch coque autonome FFA — lot P1 (firmware, aucun écran).
Lis docs/CADRAGE-PATCH-COQUE-AUTONOME.md, docs/CADRAGE-STROKE-SENSOR-DIY.md,
docs/CONVENTION-BABORD-TRIBORD.md.
Ne pas toucher AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets.
compileSdk 37, NDK 30.0.16248370. Pas de sdkmanager. Pas de windows/.

1) Plateforme : nRF52840 (Zephyr ou nRF Connect SDK).
   - I2C : BMI323 (gîte/pitch, 10 Hz), BMP390 (pression/altitude, 1 Hz),
     SHT40 (temp/humidité, 1 Hz).
   - Flash externe W25Q64 en SPI : format 16 octets/ligne (§4 cadrage).
   - Pas de BLE en mode course. Mode « download » USB/NFC séparé
     (récupération post-course).
   - Alim : LiPo 300-500 mAh, charge USB-C, gestion pile faible
     (LED + écriture marqueur fin de session).
2) Tests unitaires : parseur format flash, seuils gîte, gestion pile faible.
3) flutter analyze clean (si code Dart touché). Tests verts.

Commit : feat(patch): nrf52840 firmware v0.1 coque
Stop si analyze casse. Pas de PR fourre-tout.
```

## Lot P2 — import app DataR0w

```
Patch coque autonome FFA — lot P2 (import app).
Lis docs/CADRAGE-PATCH-COQUE-AUTONOME.md.
Ne pas toucher AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets.

1) lib/import/patch_coque.dart : parse fichier flash (binaire 16 octets/ligne)
   → SessionSample (gite_deg, pitch_deg, p_hpa, alt_baro, temp, hr).
   Champs optionnels, rétro-compat.
2) UI : bouton « Importer patch coque » sur /sessions (comme ENVOYER).
   Fichier via file_picker (USB OTG ou NFC).
3) Tests : 3 lignes fictives → SessionSample corrects.
4) flutter analyze clean. Tests verts.

Commit : feat(datar0w): patch coque import
Stop si analyze casse.
```

## Lot P3 — validation banc

```
Patch coque autonome FFA — lot P3 (validation).
Lis docs/CADRAGE-PATCH-COQUE-AUTONOME.md, docs/CADRAGE-STROKE-SENSOR-DIY.md.

1) Rejouer QEPSSL + GT9JDK + GCZEKF avec l'algo gîte du patch
   (gyro z du BMI323, tare au ponton).
2) Comparer vs gîte téléphone (baseline).
3) Critères : écart < 2° en régime stable.
4) Rapport : docs/RAPPORT-VALIDATION-PATCH-COQUE.md

Commit : docs: rapport validation patch coque
```

## Ordre

P1 → P2 → P3. P4 (mécanique) et P5 (R&D girouette) en parallèle de P3.
P6 (sync cloud) en dernier.

---

*Fin du prompt. Rien n'est codé tant que P1 n'est pas lancé.*
