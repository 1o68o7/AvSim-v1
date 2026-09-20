-- Point D / D5 — import cabane + identité club. RLS via club_members.

create table if not exists public.boat_imports (
  id uuid primary key,
  club_id uuid not null,
  created_at timestamptz not null default now(),
  created_count int not null default 0,
  updated_count int not null default 0,
  ignored_count int not null default 0
);

create table if not exists public.club_identity (
  club_id uuid primary key,
  full_name text,
  slogan text,
  founded_year int,
  primary_color int,
  secondary_color int,
  crest_path text,
  crest_storage_path text,
  updated_at timestamptz not null default now()
);

create table if not exists public.trophies (
  id uuid primary key,
  club_id uuid not null,
  name text not null,
  date date not null,
  result text
);

alter table public.boat_imports enable row level security;
alter table public.club_identity enable row level security;
alter table public.trophies enable row level security;

drop policy if exists boat_imports_all on public.boat_imports;
create policy boat_imports_all on public.boat_imports
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

drop policy if exists club_identity_all on public.club_identity;
create policy club_identity_all on public.club_identity
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

drop policy if exists trophies_all on public.trophies;
create policy trophies_all on public.trophies
  for all using (public.datar0w_in_club(club_id))
  with check (public.datar0w_in_club(club_id));

do $$
begin
  insert into storage.buckets (id, name, public)
  values ('club-crests', 'club-crests', false)
  on conflict (id) do nothing;
exception
  when undefined_table then null;
  when undefined_object then null;
end $$;
