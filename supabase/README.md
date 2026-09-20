# DataR0w — projet Supabase (point B)

Le téléphone reste utilisable **hors-ligne** (JSON `Documents/datar0w/`). Supabase est un miroir + sync. **Pas** de `samples.jsonl` dans le cloud.

## Secrets

- `SUPABASE_URL` et `SUPABASE_ANON_KEY` uniquement via `--dart-define` / secrets CI.
- **Jamais** dans le repo. **Jamais** `service_role` dans l’app.

```bash
cd apps/datar0w
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Sans dart-define, le mode local (Passer / I1–I5) continue.

## Créer le projet (dashboard, pas Cursor)

1. [supabase.com](https://supabase.com) → New project.
2. SQL Editor → coller `migrations/0001_identity_core.sql` (ou CLI `supabase db push` si le projet est lié).
3. Authentication → Providers → Email : **Magic link** ON. Redirect URL : `datarow://auth/callback`.
4. Database → Replication / Realtime : activer **assignments**, **boats**, **rowers**.
5. Copier Project URL + `anon` `public` key (pas `service_role`).

## Isolation (2 clubs / 2 users)

Fichier `tests/isolation_rls.sql` : scénario attendu (A ne voit pas B). À exécuter dans SQL Editor **après** deux comptes Auth.

## Recette 2 téléphones

Voir `docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md` §9.6.
