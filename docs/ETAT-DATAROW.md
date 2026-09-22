# DataR0w — état des lieux (vérité)

*22 septembre 2026. HEAD de référence : `main`.*

Ce fichier **gagne** sur `docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md` (en-tête périmé : I1–I5 *sont* codés), sur les briefs juillet, et sur tout agent qui voudrait rouvrir η / CAN / High-Vis.

Physique simulateur : `STATE.md` reste la vérité **AvSim**. Ce fichier est la vérité **produit club**.

---

## 0. Une phrase

**DataR0w** = app Flutter club (`apps/datar0w`). Le téléphone est un hub **entraînement**. En **compétition**, le téléphone reste au quai (FFA / World Rowing : pas de telecom en bateau). Le patch dorsal logue en local ; sync après amarrage.

Ce n’est **pas** une mesure AvSim. Watts / η / slip / RTK : hors contrat club.

---

## 1. Trois chantiers (maturité réelle)

| Chantier | Quoi | État sur `main` |
|---|---|---|
| **1 — App club Flutter** | Identité, parc, live Deck, calendrier, BLE HR, modes | **Cockpit UI livré**. Patch / sync quai = **mock** |
| **2 — Sync club (Supabase)** | Auth Google + magic link + schéma SQL | **Schéma `0001`–`0004` sur main**. Outbox séance = PR #66 (draft). Outbox identité #50 = **standby** |
| **3 — AvSim** | Moteur 1DOF + UI Analyste `web/` | **Gelé** (banc labo). Ne pas retoucher F_peak / η / check_factor |

### Standby — on y revient bientôt (ne pas jeter)

| Sujet | Où | Statut |
|---|---|---|
| Outbox identité #50 | `archive/standby-pr-50-outbox` (`8b0f603`) + ancienne ref `cursor/datarow-supabase-b1-b4-7a63` | **Standby**. Ne pas merger. Source d’idées (LWW, realtime assignments). |
| Firmware patch + GATT tél. | `docs/CADRAGE-CAPTEUR-PATCH-DORSAL.md`, `docs/BRIEF-GOODWAY-PATCH-DORSAL.md` | **Critique prochain cycle**. Remplace le mock `/quai`. |
| LSTM PyTorch force | `docs/MAIL-PITTO-LSTM-FORCE-ESTIMATION.md` | **Critique prochain cycle**. Jamais de fausse courbe F avant modèle validé. |
| AvSim 1DOF | `STATE.md`, `src/avsim/`, `web/` | Gelé comme produit. Conservé comme banc. |

---

## 2. Chantier 1 — App (`apps/datar0w`)

### 2.1 Livré et utilisable hors-ligne

- Identité I1–I8 : `/identity` `/club` `/crew` `/home/{rower,cox,coach}`
- Onboarding O1–O4 (hors Stitch) : `/auth` Google + email ; `/club/login` ; `/onboarding/rower` ; `/club/join` ; homes `/home/{intendant,director,treasurer,admin}` (squelette)
- Parc C1–C5 : `/ops/out` `/ops/in` `/ops/departure` `/ops/maintenance`
- Import D : `/club/import` **Parc | Rameurs** (preview + undo `importId`) ; `/spinoscope`
- Séance : `/` → `/presession` → `/tare` → `/live` ou `/cox` → `/quai` → `/replay`
- Coach : `/coach` OSM + notes ; `/replay-coach`
- Calendrier E/L : JSON curaté `assets/ffa_calendar_2026.json` — **zéro HTTP FFA**
- BLE : scan GATT Heart Rate `0x180D` / `0x2A37` ; refus → chip `♥ —`, GPS intact
- Auth : Google OAuth + magic link, deep link `datarow://auth/callback` ; **no-op sans clés**
- Modes : `ENTRAÎNEMENT` | `COMPÉTITION` (bandeau « tel au quai »)
- `/devices` : sangle + `DeviceType.patchDorsal` + toggles feedback (persistés)
- `/quai` : CTA « Importer patch » = **jsonl mock**

Mapping Stitch → routes : `docs/stitch-mvp/GEL.md`. Une planche = une route. Pas de 2e `/live` labo.

### 2.2 DA et conventions (ne pas rouvrir)

- Deck : `#0B0E12` / blanc / `#9AA0A6` / `#2A2F36` / CTA `#E8C547` / TRIBORD `#46C275` / BÂBORD `#E05353`
- Pas de cyan High-Vis. Pas de jargon Stitch (SYS_ID, SENSOR SYNC, PORT/STARBOARD)
- Gîte rameur : gauche écran = TRIBORD, droite = BÂBORD. Barreur : gauche = BÂBORD. `docs/CONVENTION-BABORD-TRIBORD.md`
- Pas d’Accueil sur `/live` `/cox` `/coach`. Sortie = STOP 2× → `/quai`
- Tare + Démarrer bloqués en portrait ; tare annulée si l’orientation change

### 2.3 Ce que l’UI affirme trop tôt (honnêteté)

| Affichage | Vérité |
|---|---|
| Patch dorsal pairé / log / sync | Mock store + scan fictif |
| Importer patch | Fichier jsonl local de démo |
| F estimée | **Non dispo** — pas de LSTM |
| Chip `~N licenciés` | Saisie coach, pas FFA |
| Readiness `/physio` | Placeholder sans historique FC |

---

## 3. Chantier 2 — Supabase (point B)

Détail opérationnel : `docs/CADRAGE-SUPABASE.md` + `docs/CADRAGE-SYNC-TELEMETRIE-BACKUP.md` + `supabase/README.md`.

### Sur `main` aujourd’hui

- `supabase/migrations/0001_identity_core.sql` — clubs, members, rowers, boats, assignments, RLS
- `0002_boat_ops.sql` — parc / sorties
- `0003_club_import.sql` — import cabane / storage blason
- `0004_club_roles.sql` — treasurer / intendant / director + demandes de rôle
- App : `/auth` Google + magic link, scheme `datarow://auth/callback`
- Sans `SUPABASE_URL` + `SUPABASE_ANON_KEY` : mode local, **pas de crash**

### Standby — PR #50

PR **closed dirty**. Ref archive : `archive/standby-pr-50-outbox` @ `8b0f603`.
Ancienne ref : `cursor/datarow-supabase-b1-b4-7a63` (même SHA, à ne plus utiliser dans les prompts).

Contenu à réutiliser plus tard **fichier par fichier**, jamais `git merge` :
- idées outbox LWW `updated_at` / delta pull identité
- Realtime `assignments` + chip coach
- tests RLS isolation

**Interdit dans Supabase** : `samples.jsonl`, télémétrie 1 Hz, `service_role` client, scrape FFA.

---

## 4. Chantier 3 — AvSim (gelé comme produit)

Banc labo conservé. Ne plus le traiter comme le produit club.

- Fermeture force close. Limites 1DOF documentées (`STATE.md`).
- UI Analyste `web/` + FastAPI = banc simulé. Badge **Simulé** obligatoire.
- PR juillet #8–#16 **closed stale**. Ne pas rouvrir StrokeGeometry / sensors CAN / envelope pour « faire plus joli ».

---

## 5. Git

Voir `docs/GIT-HOUSEKEEPING.md`.

- PR ouvertes draft : #65 historique séances, #66 sync télémétrie
- #50 : standby `archive/standby-pr-50-outbox` — **ne pas merger**

---

## 6. Décisions produit figées

1. Pas de capteur force sur aviron / dame de nage.
2. Entraînement = tél. hub GPS+IMU+BLE. Compétition = patch autonome, tél. au quai.
3. Force / puissance = estimation (LSTM) plus tard ; jamais une fausse courbe.
4. JSON local = vérité UI. Cloud = miroir identité / parc / méta séance + bucket télémétrie.
5. Séance sans profil (« Passer ») reste possible.
6. Un téléphone = un club actif au MVP.
7. Côté / pelles = `Assignment`, pas `Rower.sidePref`.
8. Catégorie FFA = `ageCategory(birthDate)`, jamais saisie.
9. Calendrier curaté, pas de scrape `ffaviron.fr`.
10. compileSdk 37 / NDK `30.0.16248370` : ne pas revert.

---

## 7. Prochain geste

1. Merge #65 (historique + partage) puis rebuild APK sans désinstall.
2. Merge #66 + SQL `0005`/`0006` + bucket `session-telemetry`.
3. Extraire GCZEKF, travailler les séances réelles.
4. Ensuite seulement : firmware GATT quai, puis LSTM PyTorch sur jeux réels.

Pas de nouvel écran Stitch. Pas de merge #50.
