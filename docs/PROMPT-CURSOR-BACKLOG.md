# Prompts Cursor — backlog 2026-09-30

> **Stitch d’abord** pour tout écran neuf : `docs/PROMPT-STITCH-BACKLOG.md`.
> Cadrage : `docs/CADRAGE-BACKLOG-LOTS-2026-09-30.md`.
> Une branche / un lot. Pas de fourre-tout. Pas de secrets. Pas de #50. Pas de majors Riverpod/go_router/BLE.

Règles communes à coller en tête de chaque lot :

```
Lis docs/CADRAGE-BACKLOG-LOTS-2026-09-30.md et le lot cité.
Ne pas toucher AvSim, #50, stroke DIY, patch coque, Stitch assets hors écrans du lot,
secrets, dart_defines.json, service_role.
compileSdk 37. flutter analyze clean. Tests du lot verts.
Commit conventionnel. PR hors draft si tests verts.
```

---

## Lot A1 — Google #76

Branche : `fix/datarow-google-oauth` depuis `origin/main`.

```
Lot A1 — Google OAuth bout-à-bout.
PR #76 : sortir du draft / finir supabaseOrNull typé.

1) AuthScreen : Continuer avec Google appelle le même client que email.
   supabase != null requis, sinon SnackBar « Cloud indisponible » (pas de crash).
2) Redirect : datarow://auth/callback uniquement.
   error= → écran erreur lisible, pas 404, pas /identity silencieux.
3) AuthSessionBinder : interdiction _goPostLogin si path == /identity
   sauf deep link auth réussi.
4) Tests : callback error= ; session Google mock → homeRouteForClubMemberRole.
5) README : Site URL + Redirect URLs à coller dans Supabase Dashboard.

Commit : fix(datar0w): Google OAuth callback + typed supabase
```

---

## Lot A2 — Déconnexion

Branche : `fix/datarow-signout-visible`.

```
Lot A2 — Déconnexion visible, sans wipe JSONL.

1) Bouton Déconnexion : /auth si session ; Accueil admin ; réglages rameur.
2) signOut = tokens + session Supabase seulement.
   Interdit : delete Documents/datar0w/sessions, outbox, dart_defines.
3) Après signOut → /auth (pas /identity si profil local encore là).
4) Tests : signOut conserve un dossier séance factice.

Commit : feat(datar0w): visible signOut without wiping jsonl
```

---

## Lot A3 — Portes staff (logique seulement)

Branche : `fix/datarow-staff-doors`.
UI = Stitch d’abord, puis brancher les widgets existants.

```
Lot A3 — Verrou club_members.role.

1) homeRouteForClubMemberRole : admin/directeur/intendant/trésorier/coach
   → /home/admin ou /home/coach. rower/cox → /home/rower.
2) Routes /club/* : redirect / si rôle rameur.
3) /club/login n’existe plus comme 3e Google. Post-login seulement.
4) Tests routing déjà là (étendre auth_doors).

Commit : fix(datar0w): staff vs rower route lock
```

---

## Lot C1 — STOP → sync auto

Branche : `fix/datarow-autosync-on-stop`.

```
Lot C1 — Sync auto après STOP, sans tap bandeau.

1) 2e tap STOP → /quai puis enqueue + drain si uid + activeClubId.
2) owner_user_id = auth.uid(). local_session_id = code dossier (6 lettres).
   onConflict club_id,local_session_id.
3) ACK seulement si storage zip + session_meta OK. JSONL restent.
4) Bandeau : statut LOCAL / EN FILE / CLOUD, sous AppBar,
   IgnorePointer hors chip. Plus d’overlay plein écran.
5) Tests : STOP mock → enqueue appelé ; sans uid → pas d’upload.

Commit : fix(datar0w): autosync after STOP, banner non-blocking
```

---

## Lot B2 — Liste coach cloud

Branche : `feat/datarow-club-sessions`.
Écran Stitch d’abord.

```
Lot B2 — /club/sessions.

1) Query session_meta du club actif (RLS).
2) Liste : code, date, taille, CLOUD. Vide = « Aucune séance cloud ».
3) Tap : fiche méta (pas de téléchargement zip obligatoire dans ce lot).
4) Rameur : route inaccessible (A3).
5) Tests widget + repository mock.

Commit : feat(datar0w): coach club session_meta list
```

---

## Lot B3 — session_summary

Branche : `feat/datarow-session-summary`.

```
Lot B3 — Résumés SQL, sans inventer la cadence.

1) Migration : session_summary (session_id FK, dist_m, duration_s,
   v_moy_ms, split_500_s, spm_moy nullable, gite_rms_deg).
2) Calcul local à l’arrêt + upsert cloud avec le zip.
3) spm_moy = null si cadence_src null.
4) Tests calcul sur fixture QEPSSL-like (32 s, dist connue).

Commit : feat(datar0w): session_summary upsert
```

---

## Lot B4 — Import CSV

Branche : `feat/datarow-csv-import`.

```
Lot B4 — Import coach bateaux + rameurs.

1) Parser templates assets/seed/* (ne pas casser les colonnes existantes).
2) Upsert Supabase boats / rowers / club_members. Pas de SQLite club yearly.
3) Rapport écran : N ok / N erreurs ligne.
4) Tests parseur 3 lignes bateaux + 3 rameurs.

Commit : feat(datar0w): club csv import boats and rowers
```

---

## Lot B5 — Licence FFA

Branche : `feat/datarow-ffa-licence`.

```
Lot B5 — Champ licence optionnel post-auth.

1) Onboarding rameur : n° licence optionnel.
2) Lookup table locale / agrégée seulement. Pas de scrape réseau.
3) Miss → profil loisir, pas d’erreur bloquante.
4) Tests lookup hit / miss.

Commit : feat(datar0w): optional FFA licence link
```

---

## Lot C2 — Santé (minimal)

Branche : `feat/datarow-physio-fields`.
Ne pas livrer le scan BLE complet si Point R n’est pas ouvert. Ici : schéma + null honnête.

```
Lot C2 — rower_physio + champs zip.

1) Migration rower_physio (rower_id, session_id, hr_bpm, spo2_pct, source).
2) samples.jsonl : hr_bpm / spo2_pct seulement si capteur a écrit.
3) UI : « FC non mesurée » si null.

Commit : feat(datar0w): rower_physio schema and honest nulls
```

---

## Lot C3 — Drill backup (docs + script)

```
Lot C3 — Pas d’app. Script docs/ops/restore-session-zip.md :
1) Copier 1 objet Storage → B2/S3
2) Restore + sha256
3) Checklist manuelle.
Commit : docs: session zip offsite restore drill
```

---

## Lot C4 — local_session_id = code

```
Lot C4 — Guard + SQL one-shot.
1) App : local_session_id := session.code (6 lettres).
2) docs/sql/fix-local-session-id.sql pour reliquats s1790*.
Commit : fix(datar0w): local_session_id is session code
```

---

## Lot D4 — Overlay bandeau (si C1 insuffisant)

```
Lot D4 — SessionSyncHost : SafeArea sous AppBar, IgnorePointer.
Test : tap titre AppBar atteint le leading.
Commit : fix(datar0w): sync banner does not eat taps
```

---

## Interdit dans ces lots

Play Console, majors pub, paysage LIVE (revérif manuelle seulement),
#50, Pitto, firmware, stroke/patch hardware.
