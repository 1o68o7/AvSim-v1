-- Point C / C6 — parc opérationnel (sortie, jeux de pelles, impacts).
-- RLS par club via club_members (Point B). Tables créées si absentes.

create table if not exists public.clubs (
  id uuid primary key,
  name text not null,
  short_code text,
  created_at timestamptz not null default now()
);

create table if not exists public.club_members (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null,
  role text not null default 'coach'
    check (role in ('rower', 'coach', 'admin')),
  primary key (club_id, user_id)
);

create table if not exists public.oar_sets (
  id uuid primary key,
  club_id uuid not null,
  boat_id uuid not null,
  items jsonb not null default '[]'::jsonb,
  checked_out_at timestamptz not null default now(),
  frozen boolean not null default true
);

create table if not exists public.boat_outs (
  id uuid primary key,
  club_id uuid not null,
  boat_id uuid not null,
  coach_id uuid not null,
  started_at timestamptz not null default now(),
  planned_end timestamptz,
  ended_at timestamptz,
  status text not null default 'out',
  oar_set_id uuid,
  crew_frozen boolean not null default true,
  transferred_from_coach_id uuid,
  transferred_at timestamptz,
  oars_ok boolean,
  oars_missing_note text,
  updated_at timestamptz not null default now()
);

create table if not exists public.impact_reports (
  id uuid primary key,
  club_id uuid not null,
  boat_id uuid not null,
  photo_path text,
  photo_storage_path text,
  note text not null default '',
  reported_by uuid not null,
  reported_at timestamptz not null default now(),
  status text not null default 'open'
);

create table if not exists public.checkout_queue (
  id uuid primary key,
  club_id uuid not null,
  boat_id uuid not null,
  coach_id uuid not null,
  requested_at timestamptz not null default now(),
  message text not null default ''
);

alter table public.oar_sets enable row level security;
alter table public.boat_outs enable row level security;
alter table public.impact_reports enable row level security;
alter table public.checkout_queue enable row level security;

create or replace function public.datar0w_in_club(cid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.club_members m
    where m.club_id = cid and m.user_id = auth.uid()
  );
$$;

drop policy if exists boat_outs_select on public.boat_outs;
create policy boat_outs_select on public.boat_outs
  for select using (public.datar0w_in_club(club_id));
drop policy if exists boat_outs_write on public.boat_outs;
create policy boat_outs_write on public.boat_outs
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

drop policy if exists oar_sets_all on public.oar_sets;
create policy oar_sets_all on public.oar_sets
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

drop policy if exists impact_reports_all on public.impact_reports;
create policy impact_reports_all on public.impact_reports
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

drop policy if exists checkout_queue_all on public.checkout_queue;
create policy checkout_queue_all on public.checkout_queue
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

do $$
begin
  begin
    alter publication supabase_realtime add table public.boat_outs;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

do $$
begin
  insert into storage.buckets (id, name, public)
  values ('impact-photos', 'impact-photos', false)
  on conflict (id) do nothing;
exception
  when undefined_table then null;
  when undefined_object then null;
end $$;
