# Cadrage — Supabase DataR0w (point B)

*21 septembre 2026. Complète `docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md` §9. Ce fichier gagne sur §9 si divergence d’état.*

## Statut

| Couche | Où | État |
|---|---|---|
| Migrations `0001` `0002` `0003` | `supabase/migrations/` sur **main** | À pousser dans un projet dashboard (humain) |
| `/auth` + deep link | `apps/datar0w` **main** | No-op sans dart-define |
| Outbox / LWW / Realtime Dart | branche `cursor/datarow-supabase-b1-b4-7a63` | PR #50 **closed dirty** — **ne pas merger** |
| Projet cloud live | — | **Pas créé** dans ce repo |

## Décisions figées

1. Offline-first : JSON `Documents/datar0w/` = vérité UI. Écriture locale immédiate.
2. Auth : email + magic link seulement. Redirect `datarow://auth/callback`.
3. Tenant = `clubs.id`. RLS sur toutes les tables. Pas de `service_role` client.
4. Conflits : last-write-wins sur `updated_at`.
5. **Pas** de `samples.jsonl` / IMU / GPS dans Postgres.
6. Méta séance seulement (début/fin, ids, distance, gîte max) — quand le client sync existera sur main.
7. Sans clés : « Passer » et tout I/C/D/E/R/J continuent.
8. Pas de PowerSync / Brick au MVP.

## Pourquoi #50 n’est pas sur main

- Base `fa7bbe` (20 sept) vs main `35fc866` (tare, BLE, calendrier, add-ons patch, housekeeping).
- `mergeable_state: dirty`.
- Un merge ramènerait un `lib/sync/` écrit contre un router / identity plus vieux que le Deck actuel.

Le code unique (outbox, RLS tests, realtime assignments) reste récupérable sur la branche. Prochain portage = **reprise fichier par fichier depuis main**, pas `git merge` de la branche.

## Recette projet (humain, dashboard)

1. Créer le projet Supabase.
2. SQL Editor : `0001` puis `0002` puis `0003` (ordre).
3. Auth → Email magic link ON. Redirect `datarow://auth/callback`.
4. Realtime : `assignments`, `boats`, `rowers` (quand le client Dart sera reporté).
5. Copier URL + `anon` dans `--dart-define`. Jamais `service_role`.

```bash
cd apps/datar0w
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Isolation attendue

Deux users / deux clubs : A ne lit pas B. Script prévu sur la branche #50 : `supabase/tests/isolation_rls.sql` (pas encore sur main).

## Hors scope maintenant

Rebase #50, paiement, login FFA, télémétrie cloud, multi-club par téléphone.
