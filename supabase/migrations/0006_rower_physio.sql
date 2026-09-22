-- DataR0w B.2 §3.2 — constantes rameur, opt-in santé (R6).
-- Coach lit si share_with_coach ; n'écrit pas. Rameur = soi seulement.

create table if not exists public.rower_physio (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  rower_id uuid not null references public.rowers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  consent_at timestamptz,
  share_with_coach boolean not null default false,
  resting_hr int,
  hrv_ms int,
  notes text,
  updated_at timestamptz not null default now(),
  unique (rower_id)
);

create index if not exists rower_physio_club_id_idx
  on public.rower_physio(club_id);
create index if not exists rower_physio_user_id_idx
  on public.rower_physio(user_id);

comment on table public.rower_physio is
  'Opt-in santé. Pas médical. Coach lecture seule si partage.';

alter table public.rower_physio enable row level security;

drop policy if exists rower_physio_select on public.rower_physio;
create policy rower_physio_select on public.rower_physio
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      share_with_coach
      and public.is_club_member(club_id)
      and public.club_role(club_id) in ('admin', 'coach')
    )
  );

drop policy if exists rower_physio_insert on public.rower_physio;
create policy rower_physio_insert on public.rower_physio
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_club_member(club_id)
  );

drop policy if exists rower_physio_update on public.rower_physio;
create policy rower_physio_update on public.rower_physio
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists rower_physio_delete on public.rower_physio;
create policy rower_physio_delete on public.rower_physio
  for delete to authenticated
  using (false);
