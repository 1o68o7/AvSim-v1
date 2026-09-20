# Prompt Cursor — Stitch + finaliser DataR0w

> Coller le bloc ci-dessous tel quel dans un agent Cursor.
> Repo : `1o68o7/AvSim-v1`, app : `apps/datar0w`.
> HEAD attendu : `main` (C1–C6 + D1–D5 déjà mergés).

```
DataR0w — finaliser avec Stitch. Tu es un agent de portage UI + lots restants.

## Mission
1) Lire les écrans Stitch (MCP Stitch et/ou HTML/captures dans le chat / docs).
2) Les mapper aux routes Flutter existantes.
3) Geler uniquement ce qui n’est pas encore dans l’app.
4) Coder les lots manquants dans l’ordre ci-dessous.
Ne pas relancer I1–I5 / C1–C6 / D1–D5 from scratch : ils sont sur main.

## Repo / contraintes
- Ne pas toucher AvSim (moteur simu).
- Ne pas revert compileSdk = 37 / ndkVersion "30.0.16248370".
- Pas de sdkmanager Gradle. Pas de windows/ desktop.
- Pas d’Accueil sur /live /cox /coach. Sortie séance = STOP 2× → /quai.
- DA figée : fond #0B0E12, texte blanc, labels #9AA0A6, filets #2A2F36,
  CTA #E8C547 texte noir, TRIBORD #46C275, BÂBORD #E05353.
  Pas de cyan High-Vis. Pas de jargon Stitch (SYS_ID, STAGE PROTOCOL, SENSOR SYNC).
- Convention gîte rameur : gauche écran = TRIBORD, droite = BÂBORD.
  Barreur : gauche = BÂBORD. docs/CONVENTION-BABORD-TRIBORD.md.
- Un commit par lot. flutter analyze clean. Tests du lot verts.

## Stitch — comment interagir
- Si le MCP Stitch est dispo : lister les écrans du projet, récupérer HTML.
- Copier le HTML utile dans docs/stitch-mvp/gel/ avec le mapping docs/stitch-mvp/GEL.md.
- Ignorer tout écran « labo » : watts, η, slip, RTK, 10 Hz, SOG 10HZ, horizon 3D,
  PORT/STARBOARD anglo, SYS READY.
- R2 Stitch live télémétrie dense : NE PAS remplacer /live. Extraire seulement
  le chip FC/SpO2 + pastille capteur. Le live Deck actuel reste la base.
- I5 Stitch paysage dense : /crew existe en portrait. Enrichir, ne pas dupliquer
  un deuxième écran équipage.
- C3 Stitch paysage : enrichir /ops/departure, ne pas créer une deuxième route.
- J4 et R5 = UN seul écran consentement santé (/consent).
- L5 étend /spinoscope existant, pas un deuxième spinoscope.

## Mapping gelé (ne pas recoder)

| Stitch | Route | Action |
|---|---|---|
| I1 Qui rame | /identity | polish DA si écart, pas rewrite |
| I2 Fiche rameur | /identity/edit | idem |
| I3 Mon club | /club | idem |
| I4 Fiche bateau | /club/boat | idem |
| I5 Équipage | /crew | enrichir si trou (barreur avant/arrière déjà cadré) |
| I6–I8 Accueils | /home/rower /cox /coach | idem |
| I9 empty équipage | /home/rower | vérifier empty state |
| D1 Import | /club/import | déjà là |
| D3 Identité club | /club | déjà là |
| D4 Spinoscope | /spinoscope | déjà là |
| C1 Sortie | /ops/out | déjà là |
| C2 Retour | /ops/in | déjà là |
| C3 Départ | /ops/departure | enrichir |
| C4 Impact | /ops/maintenance | déjà là |
| C5 Fiche coque ops | /club/boat | ajouter historique sorties si manquant |

Séance existante à conserver : / → /presession → /tare → /live|/cox → /quai → /replay.

## Lots à coder (ordre)

### Lot 0 — audit Stitch (aucun écran métier neuf)
- Inventaire écrans Stitch vs router.dart.
- Mettre à jour apps/datar0w/README.md : I1–I5 / C / D sont CODÉS (le README actuel ment).
- Commit : docs(datar0w): stitch map + README identité/parc/import

### Lot B — Auth Supabase (si pas déjà mergé)
Lis docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md §10 et la branche cursor/datarow-supabase-b1-b4-7a63.
Si B1–B4 incomplets : magic link, session, RLS club, garde routes /home/*.
Sans clés : mode local inchangé (pas de crash).
Commit : feat(datar0w): supabase auth guards + RLS identity

### Lot E — Calendrier FFA (4 écrans Stitch E1–E4)
Lis docs/CADRAGE-CALENDRIER-FFA-PLANS-D-EAU.md + docs/STITCH-PROMPT-POINT-E-CALENDRIER-FFA.md.
Routes : /calendar, /calendar/:id, /waters. Pin club sur /club (E4).
Données : JSON local curaté (assets), pas de scrape FFA in-app.
Toggle liste/carte OSM (même provider que le coach). Filtres chips.
CTA .ics. Deep-link inscription externe. Pas de paiement.
Commit par sous-lot : model → calendar list/map → event sheet → waters → club pin.

### Lot I live — layout blocs (pas dans les planches I1–I9)
Lis docs/CADRAGE-LIVE-RAMEUR-LAYOUT.md.
Presets sécurité / perf / nav. Mini-carte optionnelle. Ne pas casser gîte / STOP 2×.
Commit : feat(datar0w): live layout presets + mini-map

### Lot R — Cardio BLE
Lis docs/CADRAGE-CARDIO-BLE-RAMEUR.md + docs/STITCH-PROMPT-POINT-R-CARDIO-BLE.md.
R1 parser GATT 0x180D + store appareils (aucun écran).
R2 chip ♥ discret sur /live existant (pas le mock labo Stitch).
R3 axe FC replay.
R4 chip coach si sample a hrBpm.
R5 = écran /consent partagé avec J.
Pas de SDK Polar/Garmin. Pas d’ANT+. Déconnexion = ♥ —, pas de crash.

### Lot L — Après E
Lis docs/CADRAGE-COMPETITIONS-LOISIRS.md + STITCH-PROMPT-POINT-L.
Filtres régate ouverte / rando / master. Bandeau AL/AC. Signalement participation.
Import résultat = pattern Point D. Étendre /spinoscope (L5).

### Lot J — Après R1
Lis docs/CADRAGE-PROFIL-RAMEUR-PHYSIO.md + STITCH-PROMPT-POINT-J.
/devices (objets), /physio (constantes + readiness). Consentement = /consent.
Paysage J3 = même données que portrait, pas un deuxième store.

### Hors scope de CETTE session
F scraper serveur, G licenciés agrégés, patch dorsal hardware,
réservation J-1, paiement, chat, Watts/η/RTK.

## Tests minimum
- Router : chaque nouvelle route ouvre sans exception.
- E : JSON calendrier parse + filtre type.
- R : parser HR 8-bit et 16-bit.
- L : flag open_to_loisir + licence_requise.
- Analyze clean.

## Livrable de fin de session
1) Tableau Stitch → route → statut (gel / à coder / ignoré) dans docs/stitch-mvp/GEL.md.
2) README apps/datar0w à jour.
3) Commits par lot, poussés sur feat/datarow-stitch-final (PR vers main).
Stop si analyze casse. Pas de PR fourre-tout I+C+D+E+R.
```
