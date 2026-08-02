-- Server-owned preparation and rate limiting for team communications.

create table public.communication_rate_limits (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0,
  primary key (actor_user_id, team_id, action)
);

alter table public.communication_rate_limits enable row level security;
revoke all on public.communication_rate_limits from public, anon, authenticated;

create or replace function public.consume_communication_limit(
  target_team_id uuid,
  requested_action text,
  maximum_requests integer default 10,
  window_duration interval default interval '1 hour'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  limit_row public.communication_rate_limits;
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.communication_rate_limits (
    actor_user_id, team_id, action, window_started_at, request_count
  )
  values (actor_id, target_team_id, requested_action, now(), 0)
  on conflict (actor_user_id, team_id, action) do nothing;

  select *
    into limit_row
    from public.communication_rate_limits
   where actor_user_id = actor_id
     and team_id = target_team_id
     and action = requested_action
   for update;

  if limit_row.window_started_at + window_duration <= now() then
    update public.communication_rate_limits
       set window_started_at = now(), request_count = 1
     where actor_user_id = actor_id
       and team_id = target_team_id
       and action = requested_action;
  elsif limit_row.request_count >= maximum_requests then
    raise exception 'Communication rate limit exceeded';
  else
    update public.communication_rate_limits
       set request_count = request_count + 1
     where actor_user_id = actor_id
       and team_id = target_team_id
       and action = requested_action;
  end if;
end;
$$;

create or replace function public.prepare_team_invite(
  target_team_id uuid,
  invite_email text,
  invite_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(btrim(invite_email));
  resolved_name text := btrim(invite_display_name);
  actor_player_id uuid := public.current_player_id();
  target_player public.players;
  target_invite public.team_invites;
  target_team public.teams;
  raw_token text;
  expires_at_value timestamptz := now() + interval '7 days';
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Only team captains and vice-captains can send invites';
  end if;
  if normalized_email = '' or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid email address is required';
  end if;
  if resolved_name = '' or length(resolved_name) > 120 then
    raise exception 'A display name is required and must be 120 characters or fewer';
  end if;

  perform public.consume_communication_limit(target_team_id, 'team_invite', 10, interval '1 hour');

  select * into target_team from public.teams where id = target_team_id;
  if target_team.id is null then raise exception 'Team not found'; end if;

  select * into target_player
    from public.players
   where lower(email) = normalized_email
   limit 1
   for update;

  if target_player.id is null then
    insert into public.players (name, display_name, email, receive_team_notifications)
    values (resolved_name, resolved_name, normalized_email, true)
    returning * into target_player;
  end if;

  insert into public.team_memberships (team_id, player_id, role, status)
  values (target_team_id, target_player.id, 'member', 'active')
  on conflict (team_id, player_id) do update
    set status = case
      when public.team_memberships.status = 'removed' then 'active'
      else public.team_memberships.status
    end;

  raw_token := encode(extensions.gen_random_bytes(32), 'hex');

  select * into target_invite
    from public.team_invites
   where team_id = target_team_id
     and lower(email) = normalized_email
     and status = 'pending'
   limit 1
   for update;

  if target_invite.id is null then
    insert into public.team_invites (
      team_id, email, player_id, invited_by_player_id, token, expires_at
    )
    values (
      target_team_id, normalized_email, target_player.id, actor_player_id,
      raw_token, expires_at_value
    )
    returning * into target_invite;
  else
    update public.team_invites
       set token = raw_token,
           player_id = target_player.id,
           invited_by_player_id = actor_player_id,
           created_at = now(),
           expires_at = expires_at_value
     where id = target_invite.id
     returning * into target_invite;
  end if;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome,
    target_entity_type, target_entity_id, payload
  )
  values (
    auth.uid(), target_team_id, 'team_invite.prepared', 'success',
    'team_invite', target_invite.id::text,
    jsonb_build_object('expiresAt', expires_at_value)
  );

  return jsonb_build_object(
    'inviteId', target_invite.id,
    'email', normalized_email,
    'playerId', target_player.id,
    'playerName', target_player.display_name,
    'teamId', target_team.id,
    'teamName', target_team.name,
    'token', raw_token,
    'expiresAt', expires_at_value
  );
end;
$$;

create or replace function public.prepare_team_invite_resend(target_invite_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_invite public.team_invites;
  target_team public.teams;
  target_player public.players;
  actor_player_id uuid := public.current_player_id();
  raw_token text := encode(extensions.gen_random_bytes(32), 'hex');
  expires_at_value timestamptz := now() + interval '7 days';
begin
  select * into existing_invite
    from public.team_invites
   where id = target_invite_id
   for update;
  if existing_invite.id is null then raise exception 'Invite not found'; end if;
  if auth.uid() is null or not public.can_manage_team_operations(existing_invite.team_id) then
    raise exception 'Only team captains and vice-captains can resend invites';
  end if;
  if existing_invite.status <> 'pending' then raise exception 'Only pending invites can be resent'; end if;

  perform public.consume_communication_limit(existing_invite.team_id, 'team_invite', 10, interval '1 hour');

  update public.team_invites
     set token = raw_token,
         invited_by_player_id = actor_player_id,
         created_at = now(),
         expires_at = expires_at_value
   where id = target_invite_id;

  select * into target_team from public.teams where id = existing_invite.team_id;
  select * into target_player from public.players where id = existing_invite.player_id;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome,
    target_entity_type, target_entity_id, payload
  )
  values (
    auth.uid(), existing_invite.team_id, 'team_invite.resent', 'success',
    'team_invite', target_invite_id::text,
    jsonb_build_object('expiresAt', expires_at_value)
  );

  return jsonb_build_object(
    'inviteId', target_invite_id,
    'email', existing_invite.email,
    'playerId', existing_invite.player_id,
    'playerName', coalesce(target_player.display_name, existing_invite.email),
    'teamId', target_team.id,
    'teamName', target_team.name,
    'token', raw_token,
    'expiresAt', expires_at_value
  );
end;
$$;

revoke all on function public.consume_communication_limit(uuid,text,integer,interval) from public, anon, authenticated;
revoke all on function public.prepare_team_invite(uuid,text,text) from public, anon;
revoke all on function public.prepare_team_invite_resend(uuid) from public, anon;
grant execute on function public.prepare_team_invite(uuid,text,text) to authenticated;
grant execute on function public.prepare_team_invite_resend(uuid) to authenticated;
