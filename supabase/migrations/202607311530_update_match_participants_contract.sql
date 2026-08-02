create or replace function public.update_match_participants(
  operation_id uuid,
  target_match_id uuid,
  participants jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_team_id uuid;
  use_subs boolean;
  exempt_drivers boolean;
  configured_amount numeric;
  existing_response jsonb;
  result jsonb;
begin
  if auth.uid() is null or operation_id is null then raise exception 'Authentication and operation are required'; end if;
  select m.team_id, t.subs_enabled, t.drivers_void_subs, t.sub_amount
  into target_team_id, use_subs, exempt_drivers, configured_amount
  from public.matches m join public.teams t on t.id = m.team_id
  where m.id = target_match_id and not m.submitted for update;
  if target_team_id is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Draft match leadership access required';
  end if;

  select io.response into existing_response from public.idempotent_operations io
  where io.actor_user_id = auth.uid() and io.operation_id = update_match_participants.operation_id
    and io.operation_type = 'update_match_participants' and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;
  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'update_match_participants') on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  if exists (
    select 1 from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) entry
    where not exists (
      select 1 from public.team_memberships tm
      where tm.team_id = target_team_id and tm.player_id = (entry->>'playerId')::uuid and tm.status = 'active'
    )
  ) then raise exception 'A selected player is not an active team member'; end if;

  if exists (
    select 1 from public.fines f where f.match_id = target_match_id
    and not exists (
      select 1 from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) entry
      where (entry->>'playerId')::uuid = f.player_id
    )
  ) then raise exception 'Remove a player''s fines before removing them from the match'; end if;

  delete from public.match_players where match_id = target_match_id;
  insert into public.match_players (match_id, player_id, is_driver)
  select target_match_id, (entry->>'playerId')::uuid, coalesce((entry->>'isDriver')::boolean, false)
  from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) entry;

  delete from public.subs s where s.match_id = target_match_id and (
    not use_subs or not exists (
      select 1 from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) entry
      where (entry->>'playerId')::uuid = s.player_id
      and not (exempt_drivers and coalesce((entry->>'isDriver')::boolean, false))
    )
  );

  if use_subs then
    insert into public.subs (match_id, player_id, player_name, amount, paid)
    select target_match_id, p.id, coalesce(p.display_name, p.name), configured_amount, false
    from jsonb_array_elements(coalesce(participants, '[]'::jsonb)) entry
    join public.players p on p.id = (entry->>'playerId')::uuid
    where not (exempt_drivers and coalesce((entry->>'isDriver')::boolean, false))
      and not exists (select 1 from public.subs s where s.match_id = target_match_id and s.player_id = p.id);
  end if;

  result := jsonb_build_object('success', true, 'matchId', target_match_id);
  update public.idempotent_operations set response = result, completed_at = now()
  where actor_user_id = auth.uid() and idempotent_operations.operation_id = update_match_participants.operation_id;
  return result;
end;
$$;

revoke all on function public.update_match_participants(uuid, uuid, jsonb) from public, anon;
grant execute on function public.update_match_participants(uuid, uuid, jsonb) to authenticated;
notify pgrst, 'reload schema';
