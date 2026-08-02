create or replace function public.add_match_fine(
  operation_id uuid,
  target_match_id uuid,
  target_player_id uuid,
  target_fine_type_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_team_id uuid;
  player_label text;
  type_label text;
  type_cost numeric;
  fine_id uuid := gen_random_uuid();
  existing_response jsonb;
  result jsonb;
begin
  if auth.uid() is null or operation_id is null then raise exception 'Authentication and operation are required'; end if;

  select m.team_id into target_team_id from public.matches m
  where m.id = target_match_id and not m.submitted;
  if target_team_id is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Draft match leadership access required';
  end if;

  select io.response into existing_response from public.idempotent_operations io
  where io.actor_user_id = auth.uid() and io.operation_id = add_match_fine.operation_id
    and io.operation_type = 'add_match_fine' and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'add_match_fine') on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  select coalesce(p.display_name, p.name) into player_label
  from public.match_players mp join public.players p on p.id = mp.player_id
  where mp.match_id = target_match_id and mp.player_id = target_player_id;
  if player_label is null then raise exception 'Player is not selected for this match'; end if;

  select ft.name, ft.cost into type_label, type_cost from public.fine_types ft
  where ft.id = target_fine_type_id and ft.team_id = target_team_id;
  if type_label is null then raise exception 'Fine type is unavailable'; end if;

  insert into public.fines (id, match_id, player_id, fine_type_id, player_name, fine_name, cost, paid)
  values (fine_id, target_match_id, target_player_id, target_fine_type_id, player_label, type_label, type_cost, false);

  result := jsonb_build_object('success', true, 'fineId', fine_id, 'matchId', target_match_id);
  update public.idempotent_operations set response = result, completed_at = now()
  where actor_user_id = auth.uid() and idempotent_operations.operation_id = add_match_fine.operation_id;
  return result;
end;
$$;

revoke all on function public.add_match_fine(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.add_match_fine(uuid, uuid, uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
