create or replace function public.reassign_match_fine(
  operation_id uuid,
  target_team_id uuid,
  target_fine_id uuid,
  target_player_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_response jsonb;
  previous_player_id uuid;
  trusted_player_name text;
  result jsonb;
begin
  if auth.uid() is null or operation_id is null then
    raise exception 'Authentication and operation are required';
  end if;
  if not public.can_manage_team_operations(target_team_id) then
    raise exception 'Team leadership access required';
  end if;

  select io.response into existing_response
    from public.idempotent_operations io
   where io.actor_user_id = auth.uid()
     and io.operation_id = reassign_match_fine.operation_id
     and io.operation_type = 'reassign_match_fine'
     and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  select coalesce(p.display_name, p.name) into trusted_player_name
    from public.players p
    join public.team_memberships tm on tm.player_id = p.id
   where p.id = target_player_id
     and tm.team_id = target_team_id
     and tm.status = 'active';
  if trusted_player_name is null then
    raise exception 'Target player is not an active team member';
  end if;
  select f.player_id into previous_player_id
      from public.fines f
      join public.matches m on m.id = f.match_id
      join public.match_players mp on mp.match_id = m.id and mp.player_id = target_player_id
     where f.id = target_fine_id and m.team_id = target_team_id
     for update of f;
  if not found then
    raise exception 'Fine or target match player not found';
  end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'reassign_match_fine')
  on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  update public.fines f
     set player_id = target_player_id,
         player_name = trusted_player_name
    from public.matches m
   where f.id = target_fine_id
     and m.id = f.match_id
     and m.team_id = target_team_id
  ;
  if not found then raise exception 'Fine not found in team'; end if;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
  ) values (
    auth.uid(), target_team_id, 'fine.reassigned', 'success', 'fine', target_fine_id::text,
    jsonb_build_object('operationId', operation_id, 'fromPlayerId', previous_player_id, 'toPlayerId', target_player_id)
  );

  result := jsonb_build_object('success', true, 'operationId', operation_id, 'fineId', target_fine_id);
  update public.idempotent_operations
     set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = reassign_match_fine.operation_id;
  return result;
end;
$$;

revoke all on function public.reassign_match_fine(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.reassign_match_fine(uuid, uuid, uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
