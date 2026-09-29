-- DataR0w B.2 — méta séance + blob Storage.
-- Interdit : samples.jsonl / imu.jsonl / cardio dans Postgres.
-- Jamais de DELETE dur : soft-delete deleted_at (fenêtre 30 j côté client).

create table if not exists public.session_meta (
  sync_id uuid primary key,
  club_id uuid not null references public.clubs(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  rower_id uuid references public.rowers(id) on delete set null,
  local_session_id text not null,
  code text,
  class text,
  role text,
  started_at timestamptz,
  ended_at timestamptz,
  dist_m double precision,
  duration_s double precision,
  payload_sha256 text not null,
  byte_size bigint,
  storage_path text not null,
  synced_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, local_session_id)
);

create index if not exists session_meta_club_id_idx
  on public.session_meta(club_id);
create index if not exists session_meta_owner_idx
  on public.session_meta(owner_user_id);

comment on table public.session_meta is
  'Méta séance uniquement. Bytes = Storage session-telemetry. Soft-delete.';

alter table public.session_meta enable row level security;

drop policy if exists session_meta_select on public.session_meta;
create policy session_meta_select on public.session_meta
  for select to authenticated
  using (public.is_club_member(club_id));

drop policy if exists session_meta_insert on public.session_meta;
create policy session_meta_insert on public.session_meta
  for insert to authenticated
  with check (
    owner_user_id = auth.uid()
    and public.is_club_member(club_id)
  );

drop policy if exists session_meta_update on public.session_meta;
create policy session_meta_update on public.session_meta
  for update to authenticated
  using (
    owner_user_id = auth.uid()
    and public.is_club_member(club_id)
  )
  with check (
    owner_user_id = auth.uid()
    and public.is_club_member(club_id)
  );

drop policy if exists session_meta_delete on public.session_meta;
create policy session_meta_delete on public.session_meta
  for delete to authenticated
  using (false);

do $$
begin
  insert into storage.buckets (id, name, public)
  values ('session-telemetry', 'session-telemetry', false)
  on conflict (id) do nothing;
exception
  when undefined_table then null;
  when undefined_object then null;
end $$;

-- Objets : prefix club_id / <sync_id>.zip — privé.
drop policy if exists session_tel_select on storage.objects;
create policy session_tel_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'session-telemetry'
    and public.is_club_member((split_part(name, '/', 1))::uuid)
  );

drop policy if exists session_tel_insert on storage.objects;
create policy session_tel_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'session-telemetry'
    and public.is_club_member((split_part(name, '/', 1))::uuid)
  );

drop policy if exists session_tel_update on storage.objects;
create policy session_tel_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'session-telemetry'
    and public.is_club_member((split_part(name, '/', 1))::uuid)
  )
  with check (
    bucket_id = 'session-telemetry'
    and public.is_club_member((split_part(name, '/', 1))::uuid)
  );

drop policy if exists session_tel_delete on storage.objects;
create policy session_tel_delete on storage.objects
  for delete to authenticated
  using (false);
