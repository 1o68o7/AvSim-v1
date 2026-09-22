#!/usr/bin/env bash
# Backup offsite DataR0w : pg_dump (méta) + miroir Storage → S3/Backblaze.
# Jamais de samples.jsonl dans Postgres : les bytes sont dans session-telemetry.
# Secrets via l’environnement uniquement (pas dans le repo).
set -euo pipefail

STAMP="${STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
WORK="${DATAROW_BACKUP_WORK:-/tmp/datarow-backup-$STAMP}"
RETENTION_DAYS="${DATAROW_BACKUP_RETENTION_DAYS:-90}"
mkdir -p "$WORK"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL manquant — skip pg_dump (CI sans secrets = no-op)."
  exit 0
fi

echo "== pg_dump (session_meta + rower_physio + identité) =="
pg_dump "$DATABASE_URL" \
  --format=custom \
  --no-owner \
  --file="$WORK/datarow-$STAMP.dump"

echo "== Storage session-telemetry → local =="
# supabase CLI si dispo ; sinon rclone depuis un remote déjà configuré.
if command -v supabase >/dev/null 2>&1 && [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  mkdir -p "$WORK/storage/session-telemetry"
  supabase storage cp -r "ss:///session-telemetry" "$WORK/storage/session-telemetry" \
    --experimental || true
fi

echo "== Push objet HORS Supabase (S3 / Backblaze B2) =="
if [[ -z "${DATAROW_OFFSITE_URI:-}" ]]; then
  echo "DATAROW_OFFSITE_URI manquant — dump local seulement ($WORK)"
  exit 0
fi

# Ex. s3://club-datarow-offsite/  ou  b2://club-datarow-offsite/
aws s3 sync "$WORK" "$DATAROW_OFFSITE_URI/$STAMP/" --only-show-errors

CUTOFF="$(date -u -d "$RETENTION_DAYS days ago" +%Y%m%d 2>/dev/null || date -u -v-"${RETENTION_DAYS}"d +%Y%m%d)"
echo "Rétention ≥ ${RETENTION_DAYS} j (cutoff $CUTOFF). Purge liste : aws s3 ls + filtre date."
# Pas de rm automatique agressif : lister seulement.
aws s3 ls "$DATAROW_OFFSITE_URI/" || true

echo "OK $STAMP"
