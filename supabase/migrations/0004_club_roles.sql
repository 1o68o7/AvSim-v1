-- Rôles club étendus (O4). Ne casse pas admin|coach|rower|cox.
-- intendant : boats_write comme coach.
-- treasurer / director : lecture + validation des demandes de rôle.
-- Pas d'écran trésorier métier ici.

alter table public.club_members drop constraint if exists club_members_role_check;
alter table public.club_members
  add constraint club_members_role_check check (role in (
    'admin', 'coach', 'rower', 'cox',
    'treasurer', 'intendant', 'director'
  ));

drop policy if exists boats_write on public.boats;
create policy boats_write on public.boats for all to authenticated
  using (public.club_role(club_id) in ('admin', 'coach', 'intendant'))
  with check (public.club_role(club_id) in ('admin', 'coach', 'intendant'));

-- Rowers : toujours admin|coach seulement (un rameur n'écrit pas le parc humain).
-- intendant n'importe pas les rameurs.

create table if not exists public.club_join_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  requested_role text not null check (requested_role in (
    'coach', 'treasurer', 'intendant', 'director', 'rower', 'cox'
  )),
  status text not null default 'pending' check (status in (
    'pending', 'approved', 'rejected'
  )),
  created_at timestamptz not null default now()
);
create index if not exists club_join_requests_club_id_idx
  on public.club_join_requests(club_id);

alter table public.club_join_requests enable row level security;

drop policy if exists cjr_select on public.club_join_requests;
create policy cjr_select on public.club_join_requests
  for select to authenticated
  using (user_id = auth.uid() or public.is_club_member(club_id));

drop policy if exists cjr_insert on public.club_join_requests;
create policy cjr_insert on public.club_join_requests
  for insert to authenticated
  with check (user_id = auth.uid());

create or replace function public.request_club_role(p_code text, p_role text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  cid uuid;
  rid uuid;
  role_ok text;
begin
  role_ok := lower(trim(p_role));
  if role_ok not in ('coach', 'treasurer', 'intendant', 'director', 'rower', 'cox') then
    raise exception 'invalid role';
  end if;
  select id into cid from public.clubs
  where upper(coalesce(short_code, '')) = upper(trim(p_code));
  if cid is null then
    raise exception 'unknown club';
  end if;
  insert into public.club_join_requests (club_id, user_id, requested_role)
  values (cid, auth.uid(), role_ok)
  returning id into rid;
  return rid;
end;
$$;
revoke all on function public.request_club_role(text, text) from public;
grant execute on function public.request_club_role(text, text) to authenticated;

create or replace function public.approve_join_request(p_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  rec public.club_join_requests%rowtype;
  actor text;
begin
  select * into rec from public.club_join_requests where id = p_id;
  if not found then
    raise exception 'unknown request';
  end if;
  actor := public.club_role(rec.club_id);
  if actor not in ('admin', 'director') then
    raise exception 'forbidden';
  end if;
  if p_accept then
    insert into public.club_members (club_id, user_id, role)
    values (rec.club_id, rec.user_id, rec.requested_role)
    on conflict (club_id, user_id) do update set role = excluded.role;
    update public.club_join_requests set status = 'approved' where id = p_id;
  else
    update public.club_join_requests set status = 'rejected' where id = p_id;
  end if;
end;
$$;
revoke all on function public.approve_join_request(uuid, boolean) from public;
grant execute on function public.approve_join_request(uuid, boolean) to authenticated;

comment on table public.club_join_requests is
  'Demandes de rôle club. Validation admin|director. Pas d auto-promotion.';
