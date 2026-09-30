# Prompt Cursor — stroke sensor app (lots S1–S3)

> **Statut** : prompt prêt à coller. Lots S1–S3 du cadrage `docs/CADRAGE-STROKE-SENSOR-DIY.md`.
> **Date** : 2026-09-30
> **Prérequis** : point R (cardio BLE) et point H (Riverpod) mergés. flutter_blue_plus déjà en dep.

---

## Prompt (lot S1 d'abord)

```
Stroke sensor DIY — lot S1 (aucun écran).
Lis docs/CADRAGE-STROKE-SENSOR-DIY.md, docs/CADRAGE-CARDIO-BLE-RAMEUR.md,
docs/CADRAGE-TELEMETRIE-TEL.md, docs/CONVENTION-BABORD-TRIBORD.md.
Ne pas toucher AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets.
compileSdk 37, NDK 30.0.16248370. Pas de sdkmanager. Pas de windows/.

1) flutter_blue_plus déjà en dep — vérifier version lockée (pubspec.lock).
2) lib/sensors/stroke/ :
   - stroke_scanner.dart : scan filtré service 0xA000 (128-bit si besoin),
     permissions Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_CONNECT).
   - stroke_parser.dart : parse paquet 12 octets (t_ms uint32, stroke_count
     uint16, ax_peak int16 mg, gite_deg int16 ×100, battery uint8, flags uint8).
     Tests unitaires : 3 payloads (coup normal, wrap compteur, flags gyro) →
     StrokeEvent corrects.
   - stroke_hub.dart : stream StrokeEvent {tMs, strokeCount, axPeak,
     giteDeg, battery}.
3) stroke_store.dart : appareils appairés (id, name, lastSeen) en JSON local
   (Documents/datar0w/stroke_devices.json).
4) SessionSample : ajouter cadenceSpm (double?), cadenceSrc (String?) —
   optionnels, rétro-compat (absent = null).
5) Ne PAS brancher l'UI dans ce lot. Juste le hub + tests.
6) flutter analyze clean. Tests parseur verts.

Commit : feat(datar0w): stroke sensor BLE parser + hub
Stop si analyze casse. Pas de PR fourre-tout.
```

## Prompt (lot S2)

```
Stroke sensor DIY — lot S2 (chip live).
Prérequis S1 mergé.

1) StrokeHub → LiveHub : cadence_spm recalculé sur fenêtre glissante 10 s
   depuis les StrokeEvent. cadence_src = 'stroke_sensor'.
2) Chip live discret (à côté de la gîte) : « 28 spm » si capteur connecté.
   Tap → mini-panneau (batterie capteur, nom appareil, dernier coup).
3) Sans capteur : rien à afficher (le lot S3 gère le texte « cadence non mesurée »).
4) Tests : StrokeHub mock → cadence_src = 'stroke_sensor', spm cohérent.

Commit : feat(datar0w): stroke cadence chip live
Stop si analyze casse.
```

## Prompt (lot S3)

```
Stroke sensor DIY — lot S3 (UX honnête + pair screen).
Prérequis S2 mergé.

1) Partout où cadence_src == null : afficher « cadence non mesurée »
   (jamais de tiret « — », jamais de 0, jamais d'estimation IMU).
   Concerne : /live, replay, MES SÉANCES, export.
2) Écran /stroke/pair : scan, liste appareils, « Appairer », mémorise le dernier.
   Accessible depuis profil ou réglages.
3) Tests widget : sans capteur → texte « cadence non mesurée » visible.

Commit : feat(datar0w): cadence honnête + stroke pair screen
Stop si analyze casse.
```

---

## Ordre

S1 → S2 → S3 (app). S4 (firmware) et S5 (validation banc) en parallèle.
S6 (sync cloud) en dernier.
