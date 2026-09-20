# Gel Stitch → Flutter (DataR0w)

*20 sept 2026. Projet Stitch `1264451048753434333` (DataR0w Rowing Dashboard).  
Le kit `2860093974873970202` (Tx Couples) n’est **pas** porté.*

DA Deck : `#0B0E12` / blanc / `#9AA0A6` / `#2A2F36` / CTA `#E8C547` / TRIBORD `#46C275` / BÂBORD `#E05353`.  
Pas de cyan High-Vis. Pas de jargon Stitch (SYS_ID, STAGE PROTOCOL, SENSOR SYNC).  
Pas d’Accueil sur `/live` `/cox` `/coach`.

HTML utile (extraits, pas labo) : `docs/stitch-mvp/gel/`.

## Mapping

| Stitch | Route Flutter | Statut |
|---|---|---|
| Écran 1 — Qui rame ? (I2) | `/identity` | **codé** (I1) |
| Écran 2 — Fiche rameur (I2) | `/identity/edit` | **codé** (I2) |
| Écran 3 — Mon club (I3) | `/club` | **codé** (I3) |
| Écran 4 — Fiche bateau (I3) | `/club/boat` | **codé** (I4) |
| Écran 5 — Composer un équipage (I4) | `/crew` | **codé** (I5) |
| Écran 6 — Accueil Rameur (I5) | `/home/rower` | **codé** (I6) |
| Écran 7 — Accueil Barreur (I5) | `/home/cox` | **codé** (I7) |
| Écran 8 — Accueil Coach (I5) | `/home/coach` | **codé** (I8) |
| Écran 9 — Rameur sans affectation | `/home/rower` (état vide) | **codé** |
| Écran 1 — Profils DataR0w | `/` | **codé** |
| Écran 2A — Pré-session | `/presession` | **codé** |
| Écran 2B — Tare gîte (portrait) | `/tare` | **codé** |
| Écran 3 — Rameur Live Deck | `/live` | **codé** — **ne pas remplacer** par R2 dense |
| Écran 4 — Alerte gîte | `/live` (overlay) | **codé** |
| Écran 5 — Coach Live OSM | `/coach` | **codé** |
| Écran 6 — Coach Replay | `/replay-coach` | **codé** |
| Écran 7 — Quai | `/quai` | **codé** |
| Replay rameur | `/replay` | **codé** |
| D1 Import cabane | `/club/import` | **codé** (D1) |
| D2 Fiche bateau enrichie | `/club/boat` | **codé** (D) |
| D3 Identité club | `/club` | **codé** (D3) |
| D4 Spinoscope | `/spinoscope` | **codé** (D4) — L5 **étend**, pas un 2ᵉ écran |
| D5 Accueil club | `/home/coach` | **codé** |
| C1 Sortie de parc | `/ops/out` | **codé** (C1) |
| C2 Retour de parc | `/ops/in` | **codé** (C2) |
| C3 Départ / alignement | `/ops/departure` | **codé** (C3) — enrichir, pas de 2ᵉ route |
| C4 Impact | `/ops/maintenance` (+ fiche impact) | **codé** (C4) |
| C5 Fiche coque | `/club/boat` | **codé** |
| E1 Calendrier FFA | `/calendar` | **codé** |
| E2 Fiche événement | `/calendar/:id` | **codé** |
| E3 Plans d’eau | `/waters` | **codé** |
| E4 Localisation club | `/club` (pin carte) | **codé** |
| I live — presets + mini-carte | `/live` | **codé** |
| R1 Pairing BLE | `/devices` | **codé** — scan `flutter_blue_plus` GATT 0x180D / 0x2A37 ; fake CI |
| R2 Chip FC/SpO2 | overlay `/live` | **codé** (extrait, live Deck conservé) |
| R3 Courbe FC replay | `/replay` | **codé** |
| R4 Visibilité coach | chip `/coach` si `hrBpm` | **codé** |
| R5 + J4 Consentement santé | `/consent` | **codé** (un seul écran) |
| J1 Mes objets | `/devices` | **codé** |
| J2 Readiness | `/physio` | **codé** |
| J3 Mes constantes | `/physio` | **codé** |
| L1 Calendrier loisirs | `/calendar` (filtres) | **codé** |
| L2 Fiche événement loisir | `/calendar/:id` | **codé** |
| L3 Signalement | `/calendar/:id` | **codé** |
| L4 Historique rameur | `/physio` + profil | **codé** |
| L5 Spinoscope loisir | `/spinoscope` | **codé** (étend D4) |
| Auth club (Point B) | `/auth` | **codé** (local si pas de clés) |

## Ignorés (labo / doublons)

- 2B paysage labo (tangage / lacet / 18 s)
- Live télémétrie dense R2 comme **remplacement** de `/live`
- I5 Stitch paysage dense comme 2ᵉ `/crew`
- C3 Stitch paysage comme 2ᵉ `/ops/departure`
- Watts, η, slip, RTK, 10 Hz, SOG 10HZ, horizon 3D
- PORT / STARBOARD, SYS READY
- Logo DataR0w isolé
- Projet Tx Couples (`2860093974873970202`)

## Hors scope gel

F scraper FFA, G licenciés agrégés, patch dorsal, paiement, moteur AvSim.
