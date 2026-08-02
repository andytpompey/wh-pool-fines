create or replace function public.submit_match(
  operation_id uuid,
  target_match_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_match public.matches;
  existing_response jsonb;
  result jsonb;
begin
  if auth.uid() is null or operation_id is null or target_match_id is null then
    raise exception 'Authentication, operation, and match are required';
  end if;

  select io.response into existing_response
    from public.idempotent_operations io
   where io.actor_user_id = auth.uid()
     and io.operation_id = submit_match.operation_id
     and io.operation_type = 'submit_match'
     and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  select m.* into target_match
    from public.matches m
   where m.id = target_match_id
   for update;
  if target_match.id is null or not public.can_manage_team_operations(target_match.team_id) then
    raise exception 'Draft match leadership access required';
  end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'submit_match')
  on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  if target_match.submitted then
    result := jsonb_build_object(
      'success', true, 'operationId', operation_id,
      'matchId', target_match_id, 'alreadySubmitted', true
    );
  else
    if target_match.opponent is null or btrim(target_match.opponent) = '' then
      raise exception 'Opponent is required before submission';
    end if;
    if not exists (select 1 from public.match_players mp where mp.match_id = target_match_id) then
      raise exception 'At least one player is required before submission';
    end if;
    if exists (
      select 1 from public.fines f
       where f.match_id = target_match_id
         and (f.player_id is null or not exists (
           select 1 from public.match_players mp
            where mp.match_id = target_match_id and mp.player_id = f.player_id
         ))
    ) then
      raise exception 'Every fine must be assigned to a player in the match';
    end if;
    if exists (
      select 1 from public.subs s
       where s.match_id = target_match_id
         and (s.player_id is null or not exists (
           select 1 from public.match_players mp
            where mp.match_id = target_match_id and mp.player_id = s.player_id
         ))
    ) then
      raise exception 'Every sub must be assigned to a player in the match';
    end if;

    update public.matches set submitted = true where id = target_match_id;

    insert into public.audit_logs (
      actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
    ) values (
      auth.uid(), target_match.team_id, 'match.submitted', 'success', 'match', target_match_id::text,
      jsonb_build_object(
        'operationId', operation_id,
        'playerCount', (select count(*) from public.match_players where match_id = target_match_id),
        'fineCount', (select count(*) from public.fines where match_id = target_match_id),
        'subCount', (select count(*) from public.subs where match_id = target_match_id)
      )
    );

    result := jsonb_build_object(
      'success', true, 'operationId', operation_id,
      'matchId', target_match_id, 'alreadySubmitted', false
    );
  end if;

  update public.idempotent_operations
     set response = result, completed_at = now()
   where actor_user_id = auth.uid()
     and idempotent_operations.operation_id = submit_match.operation_id;
  return result;
end;
$$;

revoke all on function public.submit_match(uuid, uuid) from public, anon;
grant execute on function public.submit_match(uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
