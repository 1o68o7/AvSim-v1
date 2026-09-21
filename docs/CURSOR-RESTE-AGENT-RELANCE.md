# Prompt Cursor — relance lots B/C/D/F (branche existante)

> Coller dans un agent Cursor. **Ne pas créer de branche.** Continuer sur
> `feat/datarow-reste-agent` à HEAD actuel (contient déjà le commit doc `b9a52ae`).
> Un commit par lot, dans l'ordre. PR #54 grossit, zéro double-merge.

```
DataR0w — RELANCE. Repo 1o68o7/AvSim-v1, app apps/datar0w.
Branche courante : feat/datarow-reste-agent (NE PAS en créer une autre).
HEAD de départ : contient docs/CURSOR-RESTE-AGENT.md (commit b9a52ae).
Un commit par lot. flutter analyze clean entre chaque. Pas d'APK.

## Déjà FAIT — ne pas retoucher
- Lot A (hygiène docs) : README + GEL alignés, note PR dans le doc.
- Lot E (JSON curaté) : assets/ffa_calendar_2026.json + waters.json dans pubspec.
Ne pas re-commit, ne pas ré-écrire ces fichiers.

## Lot B — Tare paysage (cherry-pick #46)
Vérifier si le fix de cursor/datarow-tare-orientation-7a63 est dans main.
Si ABSENT :
- Bannière « POSITION DE SÉANCE » (paysage, haut du tél à gauche).
- Tare + « Démarrer » bloqués en portrait.
- Changement d'orientation après tare OK → tare annulée.
Ne pas casser le lissage gîte τ≈0,32 s ni l'invert BÂBORD/TRIBORD.
Commit : fix(datarow): tare uniquement en orientation de séance

## Lot C — Scan BLE réel (R1 durci)
Aujourd'hui : saisie locale + parser 0x2A37 sur /devices.
Cible :
- flutter_blue_plus au pubspec (si absent) : scan, connect, subscribe
  Heart Rate 0x180D / 0x2A37.
- /devices : CTA « Scanner », liste nom + RSSI, un primaire.
- Permissions Android 12+ BLUETOOTH_SCAN / CONNECT + location si exigée.
  iOS Info.plist NSBluetooth*.
- Parser 8/16 bit + RR réutilisé. Sample hr_bpm optionnel dans jsonl.
- Déconnexion / refus permission = chip ♥ — , pas de crash, logger GPS continue.
- Pas de SDK Polar/Garmin. Pas d'ANT+. Pas de diagnostic médical.
- Sans adaptateur CI : tests parser + fake scan.
Commit : feat(datarow): scan BLE GATT Heart Rate sur /devices

## Lot D — Point G mock (effectifs club)
Pas de PII rameurs.
- Champ club.licenceCountApprox (saisie coach) + chip « ~N licenciés »
  sur /club et /spinoscope.
- Label : « estimation club », pas FFA.
Commit : feat(datarow): effectif club approximatif saisi par le coach

## Lot F — Auth deep link (sans clés)
- Vérifier AndroidManifest + iOS URL scheme datarow://auth/callback.
- Sans SUPABASE_URL : /auth reste no-op « mode local ».
- Ne pas écrire de clés.
Commit : feat(datarow): deep link auth callback

## Interdit
- AvSim moteur. compileSdk / ndkVersion. windows/ desktop. sdkmanager Gradle.
- Accueil sur /live /cox /coach.
- Commit de secrets SUPABASE_* / clés Stitch.
- Scraper ffaviron.fr en live. JSON curaté seulement.
- Remplacer /live par le mock labo Stitch R2.
- Watts, η, RTK, 10 Hz, cyan High-Vis.
- Créer une nouvelle branche. Toucher aux lots A/E déjà faits.
- flutter build apk (pas de SDK agent).

DA : #0B0E12 / blanc / #9AA0A6 / #2A2F36 / CTA #E8C547 /
TRIBORD #46C275 / BÂBORD #E05353.
Gîte rameur : gauche = TRIBORD. Barreur : gauche = BÂBORD.

## Tests
flutter analyze clean.
Tests : tare orientation, parser HR, scan fake, licenceCountApprox,
JSON calendar parse.

## Hors session
Patch dorsal, paiement, F scrape live, G source FFA, polish pixel Stitch,
fermeture PR GitHub, dart-define secrets.

Stop si analyze casse. Pas de PR fourre-tout avec AvSim.
```

## Pourquoi cette relance
Le 1er passage (commit b9a52ae) a produit le doc mais aucun lot B/C/D/F.
On reprend la même branche pour éviter un double-merge. PR #54 continue.
