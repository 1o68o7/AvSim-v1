# DataR0w — projet Supabase (point B)

Le téléphone reste utilisable **hors-ligne** (JSON `Documents/datar0w/`). Supabase = miroir + sync identité / parc. **Pas** de `samples.jsonl` dans le cloud.

État au 21 sept 2026 : voir `docs/CADRAGE-SUPABASE.md` et `docs/ETAT-DATAROW.md` §3.

- Migrations `0001`–`0003` : sur **main** (schéma).
- Client Dart outbox / Realtime : branche `cursor/datarow-supabase-b1-b4-7a63` seulement. PR #50 closed dirty — ne pas merger telle quelle.
- Sans dart-define : `/auth` no-op, I1–I8 inchangés.

## Secrets

- `SUPABASE_URL` et `SUPABASE_ANON_KEY` uniquement via `--dart-define` / secrets CI.
- **Jamais** dans le repo. **Jamais** `service_role` dans l’app.

```bash
cd apps/datar0w
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Créer le projet (dashboard, pas un agent)

1. [supabase.com](https://supabase.com) → New project.
2. SQL Editor → coller **dans l’ordre** `migrations/0001_identity_core.sql`, `0002_boat_ops.sql`, `0003_club_import.sql`, `0004_club_roles.sql`.
3. Authentication → Email : **Magic link** ON. Redirect : `datarow://auth/callback`.
4. Realtime : `assignments`, `boats`, `rowers` — seulement quand le client Dart sera sur main.
5. Copier Project URL + clé `anon` `public` (pas `service_role`).

## Isolation

Le fichier `tests/isolation_rls.sql` n’est **pas** sur main (il est sur la branche #50). Ne pas inventer un scénario SQL ici.
