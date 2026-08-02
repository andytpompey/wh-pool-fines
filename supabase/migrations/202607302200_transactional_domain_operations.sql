-- Idempotent transactional operations for aggregate and privileged workflows.

create table public.idempotent_operations (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  operation_type text not null,
  response jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (actor_user_id, operation_id)
);

alter table public.idempotent_operations enable row level security;
revoke all on public.idempotent_operations from public, anon, authenticated;

create or replace function public.save_match_aggregate(
  operation_id uuid,
  aggregate jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_team_id uuid := (aggregate ->> 'teamId')::uuid;
  target_match_id uuid := (aggregate ->> 'id')::uuid;
  existing_response jsonb;
  existing_submitted boolean;
  result jsonb;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Team leadership access required';
  end if;
  if operation_id is null or target_match_id is null or target_team_id is null then
    raise exception 'Operation, match, and team are required';
  end if;

  select io.response into existing_response
    from public.idempotent_operations io
   where io.actor_user_id = auth.uid()
     and io.operation_id = save_match_aggregate.operation_id
     and io.operation_type = 'save_match_aggregate'
     and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'save_match_aggregate')
  on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  select m.submitted into existing_submitted
    from public.matches m
   where m.id = target_match_id
     and m.team_id = target_team_id
   for update;

  if existing_submitted = true
     and coalesce((aggregate ->> 'submitted')::boolean, false) = false then
    raise exception 'Submitted matches require the protected unlock operation';
  end if;

  insert into public.matches (
    id, team_id, date, season_id, opponent, submitted, venue
  )
  values (
    target_match_id,
    target_team_id,
    (aggregate ->> 'date')::date,
    nullif(aggregate ->> 'seasonId', '')::uuid,
    nullif(aggregate ->> 'opponent', ''),
    coalesce((aggregate ->> 'submitted')::boolean, false),
    coalesce(nullif(aggregate ->> 'venue', ''), 'home')
  )
  on conflict (id) do update set
    date = excluded.date,
    season_id = excluded.season_id,
    opponent = excluded.opponent,
    submitted = excluded.submitted,
    venue = excluded.venue
  where matches.team_id = excluded.team_id;

  if not found then raise exception 'Match belongs to another team'; end if;

  delete from public.match_players mp where mp.match_id = target_match_id;
  insert into public.match_players (match_id, player_id, is_driver)
  select
    target_match_id,
    (entry ->> 'playerId')::uuid,
    coalesce((entry ->> 'isDriver')::boolean, false)
  from jsonb_array_elements(coalesce(aggregate -> 'players', '[]'::jsonb)) entry;

  if exists (
    select 1 from public.fines f
     where f.match_id = target_match_id
       and not exists (
         select 1
           from jsonb_array_elements(coalesce(aggregate -> 'fines', '[]'::jsonb)) entry
          where (entry ->> 'id')::uuid = f.id
       )
  ) then
    raise exception 'Fine deletion requires a protected-action grant';
  end if;

  insert into public.fines (
    id, match_id, player_id, fine_type_id, player_name, fine_name, cost, paid
  )
  select
    (entry ->> 'id')::uuid,
    target_match_id,
    nullif(entry ->> 'playerId', '')::uuid,
    nullif(entry ->> 'fineTypeId', '')::uuid,
    entry ->> 'playerName',
    entry ->> 'fineName',
    (entry ->> 'cost')::numeric,
    coalesce((entry ->> 'paid')::boolean, false)
  from jsonb_array_elements(coalesce(aggregate -> 'fines', '[]'::jsonb)) entry
  on conflict (id) do update set
    player_id = excluded.player_id,
    fine_type_id = excluded.fine_type_id,
    player_name = excluded.player_name,
    fine_name = excluded.fine_name,
    cost = excluded.cost,
    paid = excluded.paid
  where fines.match_id = excluded.match_id;

  if exists (
    select 1 from public.subs s
     where s.match_id = target_match_id
       and not exists (
         select 1
           from jsonb_array_elements(coalesce(aggregate -> 'subs', '[]'::jsonb)) entry
          where (entry ->> 'id')::uuid = s.id
       )
  ) then
    raise exception 'Sub deletion requires a protected-action grant';
  end if;

  insert into public.subs (
    id, match_id, player_id, player_name, amount, paid
  )
  select
    (entry ->> 'id')::uuid,
    target_match_id,
    nullif(entry ->> 'playerId', '')::uuid,
    entry ->> 'playerName',
    (entry ->> 'amount')::numeric,
    coalesce((entry ->> 'paid')::boolean, false)
  from jsonb_array_elements(coalesce(aggregate -> 'subs', '[]'::jsonb)) entry
  on conflict (id) do update set
    player_id = excluded.player_id,
    player_name = excluded.player_name,
    amount = excluded.amount,
    paid = excluded.paid
  where subs.match_id = excluded.match_id;

  result := jsonb_build_object('success', true, 'matchId', target_match_id);
  update public.idempotent_operations
     set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = save_match_aggregate.operation_id;
  return result;
end;
$$;

create or replace function public.transfer_team_captain(
  operation_id uuid,
  target_team_id uuid,
  incoming_membership_id uuid,
  outgoing_membership_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_response jsonb;
  result jsonb;
begin
  if auth.uid() is null or not public.is_admin_of_team(target_team_id)
     or public.is_platform_admin() then
    raise exception 'Current captain access required';
  end if;

  select response into existing_response from public.idempotent_operations
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = transfer_team_captain.operation_id
     and operation_type = 'transfer_team_captain' and completed_at is not null;
  if existing_response is not null then return existing_response; end if;
  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'transfer_team_captain')
  on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  perform 1 from public.team_memberships
   where id in (incoming_membership_id, outgoing_membership_id)
     and team_id = target_team_id for update;

  update public.team_memberships set role = 'member'
   where id = outgoing_membership_id and team_id = target_team_id and role = 'captain';
  if not found then raise exception 'Outgoing captain is invalid'; end if;

  update public.team_memberships set role = 'captain', status = 'active'
   where id = incoming_membership_id and team_id = target_team_id and status = 'active';
  if not found then raise exception 'Incoming captain is invalid'; end if;

  insert into public.audit_logs (actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload)
  values (auth.uid(), target_team_id, 'team.captain_assignment.changed', 'success', 'team', target_team_id::text,
    jsonb_build_object('incomingMembershipId', incoming_membership_id, 'outgoingMembershipId', outgoing_membership_id));

  result := jsonb_build_object('success', true, 'teamId', target_team_id, 'incomingMembershipId', incoming_membership_id);
  update public.idempotent_operations set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = transfer_team_captain.operation_id;
  return result;
end;
$$;

create or replace function public.update_payment_batch(
  operation_id uuid,
  target_team_id uuid,
  items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_response jsonb;
  item jsonb;
  affected integer;
  updated_count integer := 0;
  result jsonb;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Team leadership access required';
  end if;

  select response into existing_response from public.idempotent_operations
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = update_payment_batch.operation_id
     and operation_type = 'update_payment_batch' and completed_at is not null;
  if existing_response is not null then return existing_response; end if;
  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'update_payment_batch')
  on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  for item in select value from jsonb_array_elements(coalesce(items, '[]'::jsonb))
  loop
    if item ->> 'kind' = 'fine' then
      update public.fines f set paid = (item ->> 'paid')::boolean
       from public.matches m
       where f.id = (item ->> 'id')::uuid and m.id = f.match_id and m.team_id = target_team_id;
    elsif item ->> 'kind' = 'sub' then
      update public.subs s set paid = (item ->> 'paid')::boolean
       from public.matches m
       where s.id = (item ->> 'id')::uuid and m.id = s.match_id and m.team_id = target_team_id;
    else
      raise exception 'Unsupported payment item';
    end if;
    get diagnostics affected = row_count;
    if affected <> 1 then raise exception 'Payment item not found in team'; end if;
    updated_count := updated_count + 1;
  end loop;

  result := jsonb_build_object('success', true, 'updatedCount', updated_count);
  update public.idempotent_operations set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = update_payment_batch.operation_id;
  return result;
end;
$$;

revoke all on function public.save_match_aggregate(uuid, jsonb) from public, anon;
revoke all on function public.transfer_team_captain(uuid, uuid, uuid, uuid) from public, anon;
revoke all on function public.update_payment_batch(uuid, uuid, jsonb) from public, anon;
grant execute on function public.save_match_aggregate(uuid, jsonb) to authenticated;
grant execute on function public.transfer_team_captain(uuid, uuid, uuid, uuid) to authenticated;
grant execute on function public.update_payment_batch(uuid, uuid, jsonb) to authenticated;

