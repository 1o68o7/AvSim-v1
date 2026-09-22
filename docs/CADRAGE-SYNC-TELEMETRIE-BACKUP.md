# Cadrage — Sync télémétrie + backup intégral (point B.2)

*22 septembre 2026. Complète `docs/CADRAGE-SUPABASE.md` §5–6 et `docs/CADRAGE-TELEMETRIE-TEL.md`. Gagne sur ces deux fichiers si divergence sur la rétention / le backup.*

## Statut

| Couche | Où | État |
|---|---|---|
| Schéma SQL `0001`–`0004` | `supabase/migrations/` sur **main** | Sur main |
| Auth Google + magic link | `apps/datar0w` **main** | Sur main |
| Outbox / sync Dart | branche #50 (closed dirty) | **Ne pas merger** — réécrire depuis main |
| Sync télémétrie + backup | `0005` `0006` + outbox Dart + CI offsite | **cette PR** (lots S1–S6) |

---

## 0. Une phrase

**Tout ce que le téléphone prélève — GPS, IMU, gîte, cadence estimée, FC/SpO2 BLE, constantes santé — est sauvegardé intégralement et durablement.** Le cloud accuse réception avant toute purge locale. Aucune donnée de séance ne disparaît silencieusement.

---

## 1. Découpage des données (figé)

| Flux | Contenu | Destination | Sync |
|---|---|---|---|
| **Master data** | clubs, rowers, boats, assignments, ops parc | Postgres (`0001`–`0004`) | Direct à l'écriture (import) |
| **Méta séance** | début/fin, code, classe, siège, distance, gîte max/RMS, device, hash | Postgres `session_meta` | Outbox → push silencieux |
| **Télémétrie brute** | `samples.jsonl`, `imu.jsonl`, notes, cardio stream | **Bucket Storage** `session-telemetry` | Upload multipart → ACK hash |
| **Santé / constantes** | poids, taille, FC repos, SpO2, consentement | Postgres `rower_physio` (opt-in) | Direct, RLS rower |
| **Identité auth** | user, club_members | `auth.users` + `club_members` | Natif Supabase |

**Interdit dans Postgres** : `samples.jsonl`, `imu.jsonl`, streams cardio bruts, blobs > 1 Mo. → Storage uniquement.

---

## 2. Contrat de non-perte (non négociable)

### 2.1 ACK avant purge
- Chaque séance poussée porte un `sync_id` (uuid) + `payload_sha256` (hash du zip/jsonl uploadé).
- Le serveur répond `{acked: true, bytes: N, sha256: …}` **après** écriture effective (row `session_meta` + objet Storage vérifié).
- Le téléphone ne marque `synced=true` et **ne purge jamais** avant ACK. Coupure réseau à mi-upload → retry, pas de perte.
- Idempotence : re-push du même `sync_id` = no-op (upsert), pas de doublon.

### 2.2 Rétention locale bornée (FIFO)
- Garde les **30 dernières séances** sur le téléphone, synced ou non.
- Purge = FIFO au-delà de 30, **jamais** avant d'avoir 30+1 synced.
- Un bug de sync ne vide pas tout d'un coup : au pire, 30 séances restent en local.
- Boot : **zéro write destructif** sur `sessions/` — lecture seule, pas de wipe « format inconnu ».

### 2.3 File de retry + alerte visible
- Outbox persistante (SQLite ou JSON) : `sync_id`, chemin fichiers, tentatives, last_error, next_retry_at.
- Drain : au lancement app, à la reprise réseau (`connectivity_plus`), au resume.
- Backoff exponentiel (1 min → 5 → 15 → 60, cap 60 min).
- Après **3 échecs** → bandeau persistant « 1 séance non synchronisée — renvoyer » (action manuelle forcée).
- Le rameur **sait** toujours s'il y a du retard. Jamais de sync silencieuse ratée.

### 2.4 Backup cloud (intégralité)
- **Postgres** : backups natifs Supabase (Pro = 7 j) + `pg_dump` quotidien hors-plateforme (script CI) → bucket objet **externe** (S3/Backblaze) que Supabase ne peut pas toucher.
- **Storage `session-telemetry`** : **PAS** couvert par les backups natifs Supabase (gap connu). Backup quotidien via API S3-compatible → même bucket externe. Restauration = 2 étapes : metadata rows puis bytes.
- **Rétention externe** : ≥ 90 jours roulants (au-delà de la fenêtre Supabase). Archive froide optionnelle (> 1 an) en format Iceberg/Parquet pour analytics longue durée.
- **Test de restauration** : trimestriel, documenté. Un backup non testé n'existe pas.
- Suppression d'une séance (rameur / RGPD) : soft-delete (`deleted_at`) + purge Storage différée 30 j. Jamais de `DELETE` dur immédiat sur les blobs.

### 2.5 Ce qui n'est PAS backupé (volontaire)
- Fichiers temporaires de cache UI, logs debug, assets embarqués.
- Secrets (`service_role`, clés) — jamais dans le repo ni le bucket.

---

## 3. Schéma (lots)

### 3.1 Postgres — `0005_session_meta.sql`
```sql
create table public.session_meta (
  id uuid primary key default gen_random_uuid(),          -- = sync_id
  club_id uuid not null references public.clubs(id) on delete cascade,
  rower_id uuid references public.rowers(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  code text,                     -- ex. GCZEKF
  boat_class text,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_s int,
  distance_m float,
  gite_max_deg float,
  gite_rms_deg float,
  device_model text,
  app_version text,
  payload_sha256 text not null,  -- hash du zip uploadé
  payload_bytes bigint,
  storage_path text,             -- chemin objet Storage
  synced_at timestamptz,         -- ACK serveur
  deleted_at timestamptz,        -- soft-delete RGPD
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index session_meta_club_idx on public.session_meta(club_id);
create index session_meta_rower_idx on public.session_meta(rower_id);
-- RLS : rower lit les siennes ; coach/admin lit le club ; personne ne DELETE dur.
```
Bucket Storage `session-telemetry` (privé, RLS par `club_id` prefix) — lot S3.

### 3.2 Physio — `0006_rower_physio.sql` (opt-in, santé)
```sql
create table public.rower_physio (
  rower_id uuid primary key references public.rowers(id) on delete cascade,
  resting_hr_bpm int,
  max_hr_bpm int,
  weight_kg float,
  height_cm float,
  consent_health boolean not null default false,
  consent_at timestamptz,
  updated_at timestamptz not null default now()
);
-- RLS : rower lit/écrit le sien seulement ; coach lit (pas d'écriture santé).
```
Champs cardio séance (`hr_bpm`, `spo2_pct`) → **dans le jsonl Storage**, pas en Postgres (trop volumineux). Seules les méta (FC moy/max) peuvent être dénormalisées dans `session_meta` si utile au coach.

---

## 4. Architecture téléphone

```
lib/session/
  session_store.dart      // vérité locale (existant, ne pas casser)
  session_sync.dart       // outbox + drain + ACK
  session_pack.dart       // zip meta+samples+imu+notes+cardio → sha256
lib/sync/
  outbox_db.dart          // SQLite : sync_id, path, attempts, next_retry
  connectivity_gate.dart  // connectivity_plus → drain
  supabase_client.dart    // upsert session_meta + upload Storage
lib/health/
  physio_store.dart       // opt-in, sync direct
```

- **Déclencheurs drain** : boot app, `connectivity_plus` (wifi/cellular up), `AppLifecycleState.resumed`, après STOP séance.
- **Jamais** de bouton « Synchroniser » pour le rameur. Silencieux. Alerte seulement si retard (> 3 échecs).
- Upload : multipart / resumable pour jsonl > 10 Mo. Reprise à l'offset en cas de coupure.

---

## 5. Lots de build (ordre)

| Lot | Contenu | Commit |
|---|---|---|
| **S1** | Cadrage + migrations `0005`/`0006` + bucket Storage (SQL + policies RLS). Aucun Dart. | `feat(datarow): session_meta schema + storage bucket` |
| **S2** | `session_pack.dart` : zip + sha256. Tests : hash stable, round-trip. | `feat(datarow): session pack + sha256` |
| **S3** | `outbox_db.dart` + `session_sync.dart` : enqueue, drain, ACK, retry, alerte. Tests : ACK manquant → pas de purge ; 3 échecs → bandeau. | `feat(datarow): session sync outbox + ACK gate` |
| **S4** | Upload Storage resumable + upsert `session_meta`. Fail-soft. Tests mock. | `feat(datarow): telemetry upload + meta upsert` |
| **S5** | `rower_physio` opt-in + sync direct + UI consentement. Tests RLS. | `feat(datarow): rower physio opt-in + sync` |
| **S6** | Script backup quotidien (pg_dump + Storage S3) → bucket externe + test restauration doc. | `chore(datarow): offsite backup pg_dump + storage` |

**Hors scope** : merge #50, Realtime coach, AvSim, firmware, secrets, Stitch, scrape FFA, ANT+, SDK Polar/Garmin.

---

## 6. Recette (bassin)

1. Séance 20 min → STOP. Fichiers locaux présents (`meta.json`, `samples.jsonl`, `imu.jsonl`).
2. Couper le réseau 2 min → rouvrir l'app : outbox en attente, **aucun fichier supprimé**.
3. Rétablir le réseau : sync silencieuse < 60 s, bandeau disparaît, `synced=true`.
4. Vérifier Supabase : row `session_meta` + objet Storage, `payload_sha256` == hash local.
5. Supprimer la séance côté app (RGPD) : soft-delete, blob Storage encore là 30 j.
6. Restaurer depuis le bucket externe (test trimestriel) : row + blob rejouables.

---

## 7. Décisions figées (ajoutent aux 10 de `ETAT-DATAROW.md`)

11. **ACK avant purge** : aucune donnée de séance n'est supprimée du téléphone avant confirmation cloud (hash + bytes).
12. **Rétention locale** : 30 dernières séances minimum, FIFO, boot non destructif.
13. **Backup externe obligatoire** : pg_dump + Storage S3 quotidien hors Supabase ; rétention ≥ 90 j ; test restauration trimestriel.
14. **Santé = opt-in + RLS rower** : `rower_physio` et streams cardio dans Storage, jamais en clair partagé coach sans consentement.
15. **Soft-delete seulement** : pas de `DELETE` dur immédiat sur blobs ni rows séance (fenêtre 30 j).

*Fin du cadrage — 22 septembre 2026.*

---

## 8. Livré (PR sync télémétrie)

Mapping SQL livré vs §3.1 : `session_meta.sync_id` = `id` ; `owner_user_id` = `user_id` ;
`class` = `boat_class` ; `dist_m` / `duration_s` / `byte_size`. Soft-delete `deleted_at`.
Bucket `session-telemetry` privé, prefix `club_id`. `0006` : `share_with_coach` +
`consent_at` (opt-in). Pas de jsonl en Postgres.

**Restauration (2 étapes)** — test trimestriel (§2.4 / recette §6.6) :

1. **Metadata** : `pg_restore --no-owner -d "$STAGING_URL" datarow-YYYYMMDD.dump`
   puis vérifier `session_meta` (`sync_id`, `payload_sha256`, `storage_path`) et
   `rower_physio`.
2. **Bytes** : recopier `storage/session-telemetry/{club_id}/{sync_id}.zip` vers le
   bucket du projet. Contrôler sha256 vs `payload_sha256`. Ne pas réinjecter le
   jsonl dans SQL.

CI : `.github/workflows/datarow-offsite-backup.yml` +
`scripts/datarow-offsite-backup.sh` (no-op sans secrets). Rétention offsite ≥ 90 j.

Calendrier drill : T1 jan / T2 avr / T3 juil / T4 oct — restore staging 1+2,
plus isolation RLS au T2, fenêtre soft-delete au T3, rotation clés au T4.

