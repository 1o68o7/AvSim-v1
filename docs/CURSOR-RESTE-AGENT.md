# Prompt Cursor — reste agent (pas d’actions humaines)

> Coller le bloc ci-dessous dans un agent Cursor.
> Hors scope agent : APK téléphone, clés Supabase, scrape FFA live, commande hardware, fermeture manuelle des PR GitHub.

```
DataR0w — reste côté agent. Repo 1o68o7/AvSim-v1, app apps/datar0w.
HEAD attendu : main ≈ c0144ff (gel Stitch + B/E/I/R/L/J).
Branche : feat/datarow-reste-agent. Un commit par lot. PR vers main.

## Interdit
- AvSim moteur. compileSdk / ndkVersion. windows/ desktop. sdkmanager Gradle.
- Accueil sur /live /cox /coach.
- Commit de secrets SUPABASE_* / clés Stitch.
- Scraper ffaviron.fr en live (ToS). JSON curaté seulement.
- Remplacer /live par le mock labo Stitch R2.
- Watts, η, RTK, 10 Hz, cyan High-Vis.

DA : #0B0E12 / blanc / #9AA0A6 / #2A2F36 / CTA #E8C547 / TRIBORD #46C275 / BÂBORD #E05353.
Gîte rameur : gauche = TRIBORD. Barreur : gauche = BÂBORD.

## Lot A — Hygiene docs
- README apps/datar0w : I/C/D/B/E/R/L/J sont CODÉS. Lister les routes nouvelles.
- docs/stitch-mvp/GEL.md : noter « R1 scan GATT à brancher » si encore « saisie locale ».
- Ne pas closer les PR GitHub (humain). Ajouter une ligne dans docs/CURSOR-RESTE-AGENT.md §PR :
  #50 B stale vs main, #52 D déjà main, #38 gel HTML stale, #46 tare à cherry-pick.
Commit : docs(datar0w): README + gel alignés post-merge Stitch

## Lot B — Tare paysage (cherry-pick #46)
Branche cursor/datarow-tare-orientation-7a63 (PR #46).
Si le fix n’est PAS dans main :
- Bannière POSITION DE SÉANCE (paysage, haut du tel à gauche).
- Tare + Démarrer bloqués en portrait.
- Changement d’orientation après tare OK → tare annulée.
Ne pas casser le lissage gîte τ≈0,32 s ni l’invert BÂBORD/TRIBORD.
Commit : fix(datar0w): tare uniquement en orientation de séance

## Lot C — Scan BLE réel (R1 durci)
Aujourd’hui : saisie locale + parser 0x2A37.
Cible :
- flutter_blue_plus (ou package déjà au pubspec) : scan, connect, subscribe Heart Rate 0x180D / 0x2A37.
- /devices : CTA « Scanner », liste nom + RSSI, un primaire.
- Permissions Android 12+ BLUETOOTH_SCAN / CONNECT + location si exigée. iOS Info.plist NSBluetooth*.
- Parser existant 8/16 bit + RR réutilisé. Sample hr_bpm optionnel dans jsonl.
- Déconnexion / refus permission = chip ♥ — , pas de crash, logger GPS continue.
- Pas de SDK Polar/Garmin. Pas d’ANT+. Pas de diagnostic médical.
- Sans adaptateur CI : tests parser + fake scan.
Commit : feat(datar0w): scan BLE GATT Heart Rate sur /devices

## Lot D — Point G mock (effectifs club)
Pas de PII rameurs. Champ club.licenceCountApprox (saisie coach) + chip « ~N licenciés » sur /club et /spinoscope.
Label : estimation club, pas FFA.
Commit : feat(datar0w): effectif club approximatif saisi par le coach

## Lot E — Point F JSON curaté (pas de scrape)
Enrichir assets calendrier / plans d’eau (quelques régates + 1 Randon’Aviron + 1 master) si le JSON est trop mince.
Script tools/ ou docs/ : format du JSON + comment un humain met à jour.
Aucun HTTP vers ffaviron.fr.
Commit : data(datar0w): calendrier FFA curaté étendu + notice MAJ

## Lot F — Auth deep link (sans clés)
Vérifier AndroidManifest + iOS URL scheme datarow://auth/callback.
Sans SUPABASE_URL : /auth reste no-op « mode local ».
Ne pas écrire de clés.
Commit : feat(datar0w): deep link auth callback

## Tests
flutter analyze clean.
Tests : tare orientation, parser HR, scan fake, licenceCountApprox, JSON calendar parse.
Pas de flutter build apk (pas de SDK agent).

## Hors session
Patch dorsal, paiement, F scrape live, G source FFA, polish pixel Stitch,
fermeture PR GitHub, dart-define secrets.

Stop si analyze casse. Pas de PR fourre-tout avec AvSim.
```

## PR GitHub à traiter **côté humain** (pas l’agent)

| PR | Sujet | Action toi |
|---|---|---|
| #50 | B Supabase older | Close : B plus récent est sur main (`19f9980`) |
| #52 | Point D | Close : déjà sur main |
| #38 | Gel HTML Deck | Close ou laisser doc ; HTML déjà dans `docs/stitch-mvp/gel/` |
| #46 | Tare orientation | Close après merge du lot B agent |

## Toi après le merge agent

```powershell
cd C:\dev\AvSim-v1
git pull
cd apps\datar0w
flutter build apk --debug
```

Puis : sangle Polar/Garmin GATT sur /devices, tare en paysage, calendrier, chip ~N licenciés.
Supabase : projet + `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` quand tu es prêt.
