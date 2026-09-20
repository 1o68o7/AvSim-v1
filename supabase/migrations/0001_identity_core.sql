-- DataR0w identité club (point B). RLS partout. Pas de samples.jsonl.
create extension if not exists pgcrypto;

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_code text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_members (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','coach','rower','cox')),
  rower_id uuid,
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);
create index club_members_user_id_idx on public.club_members(user_id);

create table public.rowers (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  display_name text not null,
  birth_date date not null,
  sex text not null check (sex in ('M','F','X')),
  weight_kg float,
  height_cm float,
  side_pref text not null default 'none' check (side_pref in ('babord','tribord','none')),
  oar_spec text,
  level text not null default 'inconnu' check (level in ('loisir','competiteur','inconnu')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index rowers_club_id_idx on public.rowers(club_id);

create table public.boats (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  class text not null,
  seats int not null,
  cox boolean not null default false,
  oar_rack text[] not null default '{}',
  status text not null default 'ready' check (status in ('ready','maintenance','out')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index boats_club_id_idx on public.boats(club_id);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  boat_id uuid not null references public.boats(id) on delete cascade,
  rower_id uuid not null references public.rowers(id) on delete cascade,
  seat_index int,
  side text check (side in ('babord','tribord')),
  oars text[] not null default '{}',
  role text not null default 'rower' check (role in ('rower','cox')),
  cox_position text check (cox_position in ('rear','front')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index assignments_club_id_idx on public.assignments(club_id);

-- helpers RLS
create or replace function public.is_club_member(p_club_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_members cm
    where cm.club_id = p_club_id and cm.user_id = auth.uid()
  );
$$;
revoke all on function public.is_club_member(uuid) from public;
grant execute on function public.is_club_member(uuid) to authenticated;

create or replace function public.club_role(p_club_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.club_members
  where club_id = p_club_id and user_id = auth.uid() limit 1;
$$;
revoke all on function public.club_role(uuid) from public;
grant execute on function public.club_role(uuid) to authenticated;

-- Créateur du club = admin (INSERT clubs sinon bloqué par club_role).
create or replace function public.handle_new_club()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  insert into public.club_members (club_id, user_id, role)
  values (new.id, auth.uid(), 'admin')
  on conflict (club_id, user_id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_club() from public;

create trigger clubs_creator_admin
after insert on public.clubs
for each row execute procedure public.handle_new_club();

create or replace function public.join_club(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  cid uuid;
begin
  select id into cid from public.clubs
  where upper(coalesce(short_code, '')) = upper(trim(p_code));
  if cid is null then
    raise exception 'unknown club';
  end if;
  insert into public.club_members (club_id, user_id, role)
  values (cid, auth.uid(), 'rower')
  on conflict (club_id, user_id) do nothing;
  return cid;
end;
$$;
revoke all on function public.join_club(text) from public;
grant execute on function public.join_club(text) to authenticated;

alter table public.clubs enable row level security;
alter table public.club_members enable row level security;
alter table public.rowers enable row level security;
alter table public.boats enable row level security;
alter table public.assignments enable row level security;

create policy clubs_select on public.clubs for select to authenticated
  using (public.is_club_member(id));
create policy clubs_insert on public.clubs for insert to authenticated
  with check (true);
create policy clubs_update on public.clubs for update to authenticated
  using (public.club_role(id) = 'admin')
  with check (public.club_role(id) = 'admin');
create policy clubs_delete on public.clubs for delete to authenticated
  using (public.club_role(id) = 'admin');

create policy cm_select on public.club_members for select to authenticated
  using (public.is_club_member(club_id));
create policy cm_write on public.club_members for all to authenticated
  using (public.club_role(club_id) = 'admin')
  with check (public.club_role(club_id) = 'admin');

create policy rowers_select on public.rowers for select to authenticated
  using (public.is_club_member(club_id));
create policy rowers_write on public.rowers for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));

create policy boats_select on public.boats for select to authenticated
  using (public.is_club_member(club_id));
create policy boats_write on public.boats for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));

create policy assignments_select on public.assignments for select to authenticated
  using (public.is_club_member(club_id));
create policy assignments_write on public.assignments for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));

alter table public.rowers replica identity full;
alter table public.boats replica identity full;
alter table public.assignments replica identity full;

comment on table public.clubs is 'Tenant DataR0w. Realtime : assignments, boats, rowers.';
