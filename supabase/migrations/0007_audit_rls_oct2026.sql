-- Audit UX 1er oct 2026 — S2 / S3 / S5.
-- S2 : session_meta + Storage = propriétaire ou staff (admin/coach/director).
-- S3 : delete autorisé pour le propriétaire (données santé / télémétrie).
-- S5 : plafonner la création de clubs (≤ 5 clubs admin par user).

create or replace function public.is_club_session_staff(p_club_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_members cm
    where cm.club_id = p_club_id
      and cm.user_id = auth.uid()
      and cm.role in ('admin', 'coach', 'director')
  );
$$;
revoke all on function public.is_club_session_staff(uuid) from public;
grant execute on function public.is_club_session_staff(uuid) to authenticated;

-- S2 — méta séances
drop policy if exists session_meta_select on public.session_meta;
create policy session_meta_select on public.session_meta
  for select to authenticated
  using (
    owner_user_id = auth.uid()
    or public.is_club_session_staff(club_id)
  );

-- S3 — suppression propriétaire (soft-delete client + hard delete RLS)
drop policy if exists session_meta_delete on public.session_meta;
create policy session_meta_delete on public.session_meta
  for delete to authenticated
  using (owner_user_id = auth.uid());

-- S2 — Storage télémétrie
drop policy if exists session_tel_select on storage.objects;
create policy session_tel_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'session-telemetry'
    and (
      public.is_club_session_staff((split_part(name, '/', 1))::uuid)
      or exists (
        select 1 from public.session_meta sm
        where sm.storage_path = name
          and sm.owner_user_id = auth.uid()
      )
    )
  );

drop policy if exists session_tel_delete on storage.objects;
create policy session_tel_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'session-telemetry'
    and exists (
      select 1 from public.session_meta sm
      where sm.storage_path = name
        and sm.owner_user_id = auth.uid()
    )
  );

-- S3 — physio : le rameur peut effacer ses constantes
drop policy if exists rower_physio_delete on public.rower_physio;
create policy rower_physio_delete on public.rower_physio
  for delete to authenticated
  using (user_id = auth.uid());

-- S5 — pas de clubs illimités
drop policy if exists clubs_insert on public.clubs;
create policy clubs_insert on public.clubs
  for insert to authenticated
  with check (
    auth.uid() is not null
    and (
      select count(*)::int
      from public.club_members cm
      where cm.user_id = auth.uid()
        and cm.role = 'admin'
    ) < 5
  );
