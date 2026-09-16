# Cursor agent — DataR0w MVP native

Coller dans Cursor Agent (Composer) à la racine de `AvSim-v1`.

```
You are implementing DataR0w, a native companion to this repo (AvSim-v1).
Do not rebuild the physics engine. Reuse existing YAML classes, FastAPI routes, and docs in /docs.

## Product lock
- Phone is the hub on a 1x footstretcher, landscape 844×390 for live instruments.
- Profiles: Rameur, Coach, Barreur (Barreur locked on 1x).
- Screens: 1 profiles, 2A pre-session, 2B tare gîte, 3 live, 4 live+alert, 5 coach live, 6 coach replay, 7 quai.
- DA: Marine Avionics Deck #0B0E12 / white / #9AA0A6 / #2A2F36 / alert #E8C547.
- No watts, no slip, no η, no Analyste, no RTK claims, no High-Vis cyan.
- Speed label always: sol — pas eau.
- Heel: GÎTE. Left of screen = BÂBORD, right = TRIBORD (rowing ref, rower faces stern). See docs/CONVENTION-BABORD-TRIBORD.md.
- Stitch freeze list: docs/STITCH-PATCH-MANQUES.md and the STITCH-PROMPT-ECRAN-*.md files.

## Stack
Flutter 3, iOS + Android, single codebase in /apps/datar0w.
State: riverpod. Routing: go_router.
Talk to existing backend if present (FastAPI on avsim-web / local). If no live session API exists, persist sessions locally (sqlite or drift) and leave a SessionApi client with TODO endpoints matching current OpenAPI if any.

## Sensors (test phone)
Must work on a physical device, not only simulator.

Android — AndroidManifest.xml:
- ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION (optional, request later)
- ACTIVITY_RECOGNITION if needed
- INTERNET
- FOREGROUND_SERVICE + FOREGROUND_SERVICE_LOCATION for session recording
Request runtime permissions before 2A continues.

iOS — Info.plist:
- NSLocationWhenInUseUsageDescription (French: suivi GPS de la séance d'aviron)
- NSMotionUsageDescription (French: gîte du bateau via l'IMU du téléphone)
- UIBackgroundModes: location (session live)
- Portrait + landscape left/right allowed; lock landscape after Démarrer.

Packages:
- geolocator (GPS SOG + distance)
- sensors_plus (accelerometer + gyroscope) + a small complementary filter or use magnetometer only if stable
- permission_handler
- battery_plus
- connectivity_plus (chip 4G / hors ligne — no RTK)

Tare 2B: 30s average of roll while still. Store zero offset. Live gîte = roll - offset. Clamp display ±15°.
Cadence v1: peak detect on surge or use a simple stroke counter from longitudinal accel; if unreliable, show cadence as « — » rather than invent SPM.
Never label GPS speed as water speed.

## App structure
/apps/datar0w
  lib/
    main.dart
    theme/deck_theme.dart
    sensors/gps_service.dart
    sensors/imu_service.dart
    sensors/permissions.dart
    session/session_model.dart
    session/session_store.dart
    features/profile/screen_1.dart
    features/presession/screen_2a.dart
    features/tare/screen_2b.dart
    features/live/screen_3.dart
    features/live/screen_4_alert.dart  // same as 3 + banner if |gite| > 3° toward tribords
    features/coach/screen_5.dart
    features/coach/screen_6.dart
    features/quai/screen_7.dart

Implement UI close to frozen Stitch HTML intent, not pixel-perfect. Prioritize readable landscape live.

## Flow
1 → 2A → 2B → 3 (4 overlays when |gîte| > 3° tribords) → STOP → 7.
Coach from 1 → 5 (map placeholder + live numbers via local demo or future 4G). Replay 6 reads last session file.
Barreur on 1x: disabled.

## Done when
- flutter run on a real iPhone or Android: permissions dialogs appear, GPS updates, IMU roll moves when you tilt the phone, tare zeros it.
- Landscape live shows cadence-or-dash, SOG, distance, gîte with BÂBORD left.
- Session file written on STOP.
- README in /apps/datar0w: how to run, permissions, mount landscape on footstretcher.
Do not add sensor shopping UI. Do not port the web Analyste console.
```
