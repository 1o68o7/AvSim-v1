# Backlog lots — vérité 2026-09-30

> **Statut** : cadrage figé. Rien à coder ici.
> **Exécution** :
> - Cursor → `docs/PROMPT-CURSOR-BACKLOG.md`
> - Stitch → `docs/PROMPT-STITCH-BACKLOG.md`
> **Hors scope de ce lot** : stroke sensor DIY, patch coque FFA, #50 LSTM/firmware, mail Pitto, proto.

Ordre utile (déjà validé) :

1. **#76 Google**
2. **STOP → sync sans tap bandeau**
3. **Liste coach des séances cloud**

Ensuite : résumés SQL, déconnexion, portes staff, import CSV, licence FFA, store.

---

## 0. Déjà livré dans cet arc (ne pas refaire)

Dart-defines locaux, schéma Supabase, Lots UX A/B/C, MES SÉANCES + export WhatsApp, portes auth (#70), fix clics (#72), `owner_user_id` (#69), retry outbox, `activeClubId`, upsert `session_meta` (#79), 3 séances en Storage.

Frigo volontaire : PR **#50** (archive standby), mail Pitto + proto, firmware téléphone / patch accès capteurs.

---

## A — Auth / parcours

### A1. Google — PR #76

**Constat.** Email / magic link marche. Google casse encore (`supabaseOrNull` typé, callback `datarow://auth/callback` partiellement corrigé, pas retesté bout-à-bout).

**Cible.** Un tap « Continuer avec Google » → session Supabase → `homeRouteForClubMemberRole`. Pas de 404, pas de retour silencieux sur `/identity`.

**Vérif.** Rebuild APK + Google une fois. SQL : `auth.users` a l’uid. Deep link : ouvrir `datarow://auth/callback?code=…` sans page blanche.

**Hors scope.** Nouveau SDK, majors Riverpod/go_router.

### A2. Déconnexion visible sans wipe JSONL

**Constat.** `signOut` existe (#70) mais n’est pas trouvable. Tester = vider cache Android = risque de perdre les séances locales.

**Cible.** Bouton **Déconnexion** sur `/auth` (session active) et sur Accueil admin / réglages. `signOut` = tokens seulement. JSONL + outbox intacts.

### A3. Portes staff vs rameur

**Constat.** Cadrage écrit (`CADRAGE-ONBOARDING-ROLES`, portes #70). UI club mince. Cartes Rameur / Coach / Barreur encore trop proches des portes staff (directeur, intendant, trésorier).

**Cible.**

```
Boot → /identity
  profil local → /home/rower (ou onboard)
  Connexion → /auth → staff → /home/{admin|coach|…}
                         rameur → /home/rower
  Espace club = post-login seulement (infos club, pas une 3e porte Google)
```

Staff : import, demandes, séances club. Rameur : MES SÉANCES + LIVE. Verrou `club_members.role`.

### A4. Deep link callback

**Cible.** Site URL + Redirect URLs Supabase = `datarow://auth/callback` uniquement (pas `localhost:3000datarow://…`). Route Flutter `error=` → écran erreur, pas 404. Test Google + magic link.

---

## B — Produit rameur / coach

### B1. Écrans Stitch collés aux add-on

**Constat.** Premier prompt de l’arc. DA Deck (#0B0E12) partiel. Stitch doit produire les écrans manquants **avant** Cursor UI.

**Écrans à dessiner (voir prompt Stitch).** Déconnexion, accueil staff, liste coach cloud, fiche résumé séance, import CSV, liaison licence FFA, réglages capteurs (placeholder), bandeau sync discret.

### B2. Vue coach — séances cloud du club

**Constat.** Storage + `session_meta` ont des rows. Aucun écran coach ne les liste.

**Cible.** `/club/sessions` (rôle coach/admin). Colonnes : `code`, `started_at`, `owner`, `byte_size`, statut CLOUD. Tap → méta + lien zip (pas le replay IMU dans ce lot). RLS : `is_club_member`.

SQL de contrôle :

```sql
select code, owner_user_id, storage_path, byte_size, synced_at
from public.session_meta
order by created_at desc;
```

### B3. Résumés séance en base

**Constat.** 500 m, km/h, eq/500, SPM, gîte encore calculés à la main / replay local. `cadence_spm` souvent null (pas de stroke sensor).

**Cible.** Table `session_summary` (ou colonnes sur `session_meta`) :

| Champ | Source |
|---|---|
| `dist_m` | GPS samples |
| `duration_s` | meta start/end |
| `v_moy_ms` / `v_moy_kmh` | dist / duration |
| `split_500_s` | 500 / v_moy |
| `spm_moy` | cadence si `cadence_src` non null, sinon **null** |
| `gite_rms_deg` | samples |

Règle : **jamais inventer** la cadence. Null → UI « cadence non mesurée ».

### B4. Import CSV bateaux + 500 licenciés loisir

**Constat.** Seeds `assets/seed/rameurs_bordeaux*.csv` existent. Import coach encore fragile.

**Cible.** Deux templates figés + écran import :
- bateaux (parc Bordeaux déjà cadré)
- rameurs (compétition scrapée + 500 loisir 50/50 H/F, 35–75 ans)

Stockage : Supabase (`boats`, `rowers`, `club_members`), pas le téléphone. Yearly, pas daily.

### B5. Liaison licence FFA à l’inscription

**Cible.** Après Google/email, champ optionnel n° licence. Lookup local / table agrégée (voir `CADRAGE-FFA-LICENCIES-AGREGES`). Pas de scrape live dans l’app. Rameur sans licence = loisir OK.

---

## C — Sync / data

### C1. Sync 100 % auto après STOP

**Constat.** Drain + `enqueueExistingLocalSessions` existent. Validé au tap « renvoyer », pas au seul STOP.

**Cible.** STOP 2e tap → `/quai` → si `auth.uid()` + `activeClubId` : enqueue + drain **sans tap bandeau**. Bandeau = statut seulement (LOCAL / EN FILE / CLOUD), hit-test ne bloque plus l’AppBar.

ACK seulement si zip + row `session_meta` OK. Pas de delete JSONL local.

### C2. Santé dans le zip + `rower_physio`

**Constat.** Champs `hr_bpm` / `spo2_pct` dans samples, encore null. Point R (cardio BLE) cadré, pas livré.

**Cible.** Si sangle GATT `0x180D` : écrire HR dans samples + zip. Table `rower_physio` (opt-in). Sans capteur : champs absents, pas de 0 inventé.

### C3. Miroir S3/B2 + drill restore

**Constat.** Écrit dans #66, jamais exercé.

**Cible.** Doc + un run manuel : copie d’un zip Storage → B2/S3, restore test, checksum. Pas de code app.

### C4. `local_session_id` = `code`

**Constat.** 2 lignes corrigées à la main (`s1790…` vs `QEPSSL`). Unique `(club_id, local_session_id)`.

**Cible.** Toujours `code` dossier (6 lettres). Jamais `s`+epoch. Migration one-shot SQL si reliquats.

---

## D — App / store

### D1. Play Protect / keystore release

Même keystore à chaque APK. Documenter le chemin (hors git). Sideload : « Installer quand même ». Play Console plus tard, pas ce lot.

### D2. Majors deps

**Interdit** de mélanger avec auth/sync. Lot dédié plus tard : `pub upgrade` safe d’abord, puis Riverpod 3, go_router 18, flutter_blue_plus 2 **un par un**.

### D3. Paysage LIVE

#72 a locké portrait sur hubs `/identity` `/auth` `/home/*`. LIVE / cox : revérifier paysage (3 colonnes). Ne pas casser le lock hubs.

### D4. Overlay bandeau vs AppBar

`SessionSyncHost` : bandeau sous l’AppBar, `IgnorePointer` hors chip. Plus d’écran « incliquable ».

---

## E — Frigo (ne pas ouvrir)

| Item | Pourquoi |
|---|---|
| PR #50 outbox LSTM / firmware | Archive standby, très important plus tard |
| Mail Pitto + proto | Hors produit app |
| Firmware téléphone / patch capteurs | Lié stroke + patch coque, autre cadrage |

---

## Définition of done (lot utile)

- [ ] #76 Google mergée, testée sur OnePlus
- [ ] STOP → row `session_meta` sans tap bandeau (SQL count +)
- [ ] `/club/sessions` liste les zips du club
- [ ] Déconnexion visible, JSONL conservés
- [ ] Cadence absente → texte « non mesurée »
