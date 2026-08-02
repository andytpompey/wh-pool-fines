-- Consume a short-lived unlock grant in the same transaction as its mutation.

create or replace function public.execute_protected_action(
  grant_token uuid,
  target_entity_type text,
  target_entity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  consumed_grant public.protected_action_grants;
  expected_action text;
  affected_rows integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  expected_action := case target_entity_type
    when 'match' then 'delete_match'
    when 'fine' then 'delete_fine_entry'
    when 'sub' then 'delete_fine_entry'
    when 'fine_type' then 'delete_fine_type'
    when 'season' then 'delete_season'
    when 'team_membership' then 'remove_team_member'
    when 'match_unlock' then 'unlock_match'
    else null
  end;

  if expected_action is null then
    raise exception 'Unsupported protected target';
  end if;

  update public.protected_action_grants pag
     set consumed_at = now()
   where pag.token = grant_token
     and pag.actor_user_id = auth.uid()
     and pag.action = expected_action
     and pag.consumed_at is null
     and pag.expires_at > now()
  returning pag.* into consumed_grant;

  if consumed_grant.token is null then
    raise exception 'Grant is invalid, expired, used, or for another action';
  end if;

  if not public.is_team_leader(consumed_grant.team_id)
     or public.is_platform_admin() then
    raise exception 'Protected-action authority is no longer valid';
  end if;

  perform set_config('app.protected_action_grant', consumed_grant.token::text, true);

  case target_entity_type
    when 'match' then
      delete from public.matches m
       where m.id = target_entity_id
         and m.team_id = consumed_grant.team_id;
    when 'fine' then
      delete from public.fines f
       using public.matches m
       where f.id = target_entity_id
         and m.id = f.match_id
         and m.team_id = consumed_grant.team_id;
    when 'sub' then
      delete from public.subs s
       using public.matches m
       where s.id = target_entity_id
         and m.id = s.match_id
         and m.team_id = consumed_grant.team_id;
    when 'fine_type' then
      delete from public.fine_types ft
       where ft.id = target_entity_id
         and ft.team_id = consumed_grant.team_id;
    when 'season' then
      delete from public.seasons s
       where s.id = target_entity_id
         and s.team_id = consumed_grant.team_id;
    when 'team_membership' then
      delete from public.team_memberships tm
       where tm.id = target_entity_id
         and tm.team_id = consumed_grant.team_id
         and tm.player_id <> public.current_player_id()
         and tm.role <> 'captain';
    when 'match_unlock' then
      update public.matches m
         set submitted = false
       where m.id = target_entity_id
         and m.team_id = consumed_grant.team_id
         and m.submitted = true;
  end case;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Protected target was not found or cannot be changed';
  end if;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type,
    target_entity_id, payload
  )
  values (
    auth.uid(),
    consumed_grant.team_id,
    case when target_entity_type = 'match_unlock'
      then 'protected_record.reversed'
      else 'protected_record.deleted'
    end,
    'success',
    target_entity_type,
    target_entity_id::text,
    jsonb_build_object('protectedAction', expected_action)
  );

  return jsonb_build_object(
    'success', true,
    'action', expected_action,
    'targetEntityType', target_entity_type,
    'targetEntityId', target_entity_id
  );
end;
$$;

revoke all on function public.execute_protected_action(uuid, text, uuid)
  from public, anon;
grant execute on function public.execute_protected_action(uuid, text, uuid)
  to authenticated;

create or replace function public.guard_match_unlock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.submitted = true
     and new.submitted = false
     and nullif(current_setting('app.protected_action_grant', true), '') is null then
    raise exception 'Unlocking a submitted match requires a protected-action grant';
  end if;
  return new;
end;
$$;

drop trigger if exists matches_guard_unlock on public.matches;
create trigger matches_guard_unlock
before update of submitted on public.matches
for each row execute function public.guard_match_unlock();

revoke all on function public.guard_match_unlock() from public, anon, authenticated;

-- Operational inserts and updates remain leader-authorized, while protected
-- deletes are possible only through execute_protected_action.
drop policy if exists "team scoped write" on public.fine_types;
create policy "team scoped insert" on public.fine_types
for insert to authenticated
with check (public.can_manage_team_operations(team_id));
create policy "team scoped update" on public.fine_types
for update to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.seasons;
create policy "team scoped insert" on public.seasons
for insert to authenticated
with check (public.can_manage_team_operations(team_id));
create policy "team scoped update" on public.seasons
for update to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.matches;
create policy "team scoped insert" on public.matches
for insert to authenticated
with check (public.can_manage_team_operations(team_id));
create policy "team scoped update" on public.matches
for update to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.fines;
create policy "team scoped insert" on public.fines
for insert to authenticated
with check (
  exists (
    select 1 from public.matches m
     where m.id = fines.match_id
       and public.can_manage_team_operations(m.team_id)
  )
);
create policy "team scoped update" on public.fines
for update to authenticated
using (
  exists (
    select 1 from public.matches m
     where m.id = fines.match_id
       and public.can_manage_team_operations(m.team_id)
  )
)
with check (
  exists (
    select 1 from public.matches m
     where m.id = fines.match_id
       and public.can_manage_team_operations(m.team_id)
  )
);

drop policy if exists "team scoped write" on public.subs;
create policy "team scoped insert" on public.subs
for insert to authenticated
with check (
  exists (
    select 1 from public.matches m
     where m.id = subs.match_id
       and public.can_manage_team_operations(m.team_id)
  )
);
create policy "team scoped update" on public.subs
for update to authenticated
using (
  exists (
    select 1 from public.matches m
     where m.id = subs.match_id
       and public.can_manage_team_operations(m.team_id)
  )
)
with check (
  exists (
    select 1 from public.matches m
     where m.id = subs.match_id
       and public.can_manage_team_operations(m.team_id)
  )
);

drop policy if exists "team scoped write" on public.team_memberships;
create policy "team membership insert" on public.team_memberships
for insert to authenticated
with check (public.is_admin_of_team(team_id));
create policy "team membership update" on public.team_memberships
for update to authenticated
using (public.is_admin_of_team(team_id))
with check (public.is_admin_of_team(team_id));
