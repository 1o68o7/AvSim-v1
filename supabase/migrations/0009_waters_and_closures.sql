-- DataR0w funnel reste — waters / club_waters / water_closures.
-- Ne recrée pas clubs, boat_outs, assignments, licenses, session_meta.
-- RLS déjà on ailleurs : policies ajoutées ici seulement.

-- —— waters (référentiel bassin) ——
create table if not exists public.waters (
  id text primary key,
  name text not null,
  type text,
  city text,
  lat double precision,
  lon double precision,
  length_m integer,
  created_at timestamptz not null default now()
);

comment on table public.waters is
  'Plans d’eau FFA / club. Pas un club. Géofence ultérieure.';

alter table public.waters enable row level security;

drop policy if exists waters_select on public.waters;
create policy waters_select on public.waters
  for select to authenticated
  using (true);

-- —— club_waters (rattachement) ——
create table if not exists public.club_waters (
  club_id uuid not null references public.clubs(id) on delete cascade,
  water_id text not null references public.waters(id) on delete cascade,
  primary key (club_id, water_id)
);

alter table public.club_waters enable row level security;

drop policy if exists club_waters_select on public.club_waters;
create policy club_waters_select on public.club_waters
  for select to authenticated
  using (
    exists (
      select 1 from public.club_members m
      where m.club_id = club_waters.club_id and m.user_id = auth.uid()
    )
  );

drop policy if exists club_waters_write on public.club_waters;
create policy club_waters_write on public.club_waters
  for all to authenticated
  using (
    exists (
      select 1 from public.club_members m
      where m.club_id = club_waters.club_id
        and m.user_id = auth.uid()
        and m.role in ('coach', 'admin', 'director')
    )
  )
  with check (
    exists (
      select 1 from public.club_members m
      where m.club_id = club_waters.club_id
        and m.user_id = auth.uid()
        and m.role in ('coach', 'admin', 'director')
    )
  );

-- —— water_closures (veto bassin) ——
create table if not exists public.water_closures (
  id uuid primary key default gen_random_uuid(),
  water_id text not null references public.waters(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text not null,
  note text,
  created_by uuid references auth.users(id),
  club_id uuid references public.clubs(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists water_closures_water_id_idx
  on public.water_closures(water_id);

comment on table public.water_closures is
  'Veto coach sur un bassin + plage. Ne remplace pas boat_outs.status.';

alter table public.water_closures enable row level security;

drop policy if exists water_closures_select on public.water_closures;
create policy water_closures_select on public.water_closures
  for select to authenticated
  using (
    club_id is null
    or exists (
      select 1 from public.club_members m
      where m.club_id = water_closures.club_id and m.user_id = auth.uid()
    )
  );

drop policy if exists water_closures_insert on public.water_closures;
create policy water_closures_insert on public.water_closures
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      club_id is null
      or exists (
        select 1 from public.club_members m
        where m.club_id = water_closures.club_id
          and m.user_id = auth.uid()
          and m.role in ('coach', 'admin', 'director')
      )
    )
  );

drop policy if exists water_closures_delete on public.water_closures;
create policy water_closures_delete on public.water_closures
  for delete to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1 from public.club_members m
      where m.club_id = water_closures.club_id
        and m.user_id = auth.uid()
        and m.role in ('coach', 'admin', 'director')
    )
  );
