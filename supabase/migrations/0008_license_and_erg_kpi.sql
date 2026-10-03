-- DataR0w funnel rameur Lot 1 — licences FFA + KPI erg sur session_meta.
-- Ne recrée pas clubs / rowers / session_meta. Pas de profiles / erg_logs / outings.

-- —— licenses (liée au rameur, pas une table profiles) ——
create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  rower_id uuid not null references public.rowers(id) on delete cascade,
  license_number text,
  license_type text,
  valid_until date,
  ffa_code text,
  category text,
  surclassement boolean not null default false,
  handi_classification text,
  source text,
  myffa_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (rower_id, license_number)
);

create index if not exists licenses_rower_id_idx
  on public.licenses(rower_id);

comment on table public.licenses is
  'Licence FFA par rameur. PDF non stocké. ffa_code = structure, pas clubs.short_code.';

alter table public.licenses enable row level security;

drop policy if exists licenses_select on public.licenses;
create policy licenses_select on public.licenses
  for select to authenticated
  using (
    exists (
      select 1 from public.rowers r
      where r.id = rower_id and r.user_id = auth.uid()
    )
  );

drop policy if exists licenses_insert on public.licenses;
create policy licenses_insert on public.licenses
  for insert to authenticated
  with check (
    exists (
      select 1 from public.rowers r
      where r.id = rower_id and r.user_id = auth.uid()
    )
  );

drop policy if exists licenses_update on public.licenses;
create policy licenses_update on public.licenses
  for update to authenticated
  using (
    exists (
      select 1 from public.rowers r
      where r.id = rower_id and r.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.rowers r
      where r.id = rower_id and r.user_id = auth.uid()
    )
  );

-- —— session_meta KPI erg (nullable) ——
alter table public.session_meta
  add column if not exists split_500_s double precision;

alter table public.session_meta
  add column if not exists cadence double precision;

alter table public.session_meta
  add column if not exists watts double precision;

alter table public.session_meta
  add column if not exists drag_factor double precision;

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'session_meta'
      and column_name = 'origin'
  ) then
    alter table public.session_meta
      add column origin text
      check (origin is null or origin in ('indoor', 'remplacement'));
  end if;
end $$;

-- —— clubs.ffa_code (ne pas toucher short_code) ——
alter table public.clubs
  add column if not exists ffa_code text;
