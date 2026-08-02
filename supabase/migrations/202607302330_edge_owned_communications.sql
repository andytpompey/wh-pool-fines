-- Only the trusted Edge Function may receive communication secrets or recipient lists.

revoke all on function public.prepare_team_invite(uuid,text,text) from authenticated;
revoke all on function public.prepare_team_invite_resend(uuid) from authenticated;

create or replace function public.prepare_team_invite_as_service(
  actor_user_id uuid,
  target_team_id uuid,
  invite_email text,
  invite_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'Service role required';
  end if;
  if not exists (select 1 from auth.users where id = actor_user_id) then
    raise exception 'Actor not found';
  end if;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', actor_user_id, 'role', 'authenticated')::text,
    true
  );
  return public.prepare_team_invite(target_team_id, invite_email, invite_display_name);
end;
$$;

create or replace function public.prepare_team_invite_resend_as_service(
  actor_user_id uuid,
  target_invite_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'Service role required';
  end if;
  if not exists (select 1 from auth.users where id = actor_user_id) then
    raise exception 'Actor not found';
  end if;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', actor_user_id, 'role', 'authenticated')::text,
    true
  );
  return public.prepare_team_invite_resend(target_invite_id);
end;
$$;

create or replace function public.prepare_unlock_reset_as_service(
  actor_user_id uuid,
  target_team_id uuid,
  reset_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_is_platform_admin boolean;
  actor_is_captain boolean;
  generated_code text;
  target_team public.teams;
  recipients jsonb;
  rotated_at timestamptz := now();
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'Service role required';
  end if;
  if reset_reason not in ('captain_recovery', 'platform_admin_reset') then
    raise exception 'Unsupported reset reason';
  end if;

  select exists (
    select 1 from public.app_users
     where id = actor_user_id and is_platform_admin = true
  ) into actor_is_platform_admin;
  select exists (
    select 1
      from public.team_memberships tm
      join public.players p on p.id = tm.player_id
     where tm.team_id = target_team_id
       and tm.status = 'active'
       and tm.role = 'captain'
       and p.user_id = actor_user_id
  ) into actor_is_captain;

  if reset_reason = 'captain_recovery' and not actor_is_captain then
    raise exception 'Only the team captain can recover the unlock code';
  end if;
  if reset_reason = 'platform_admin_reset' and not actor_is_platform_admin then
    raise exception 'Only a platform administrator can trigger this reset';
  end if;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', actor_user_id, 'role', 'authenticated')::text,
    true
  );
  perform public.consume_communication_limit(target_team_id, 'unlock_reset', 3, interval '1 hour');

  select * into target_team from public.teams where id = target_team_id for update;
  if target_team.id is null then raise exception 'Team not found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'email', p.email,
    'playerName', p.display_name
  )), '[]'::jsonb)
    into recipients
    from public.team_memberships tm
    join public.players p on p.id = tm.player_id
   where tm.team_id = target_team_id
     and tm.status = 'active'
     and tm.role = 'captain'
     and p.receive_team_notifications = true
     and p.email is not null
     and p.email not like '%@placeholder.local';

  if jsonb_array_length(recipients) = 0 then
    raise exception 'No eligible captain notification recipients';
  end if;

  generated_code := (
    select string_agg((get_byte(extensions.gen_random_bytes(1), 0) % 10)::text, '')
      from generate_series(1, 6)
  );

  update public.teams
     set unlock_code_hash = extensions.crypt(generated_code, extensions.gen_salt('bf', 12)),
         unlock_code_salt = null,
         unlock_code_hash_algorithm = 'bcrypt',
         unlock_code_hash_iterations = 12,
         unlock_code_version = 2,
         unlock_code_reset_required = false,
         unlock_code_last_rotated_at = rotated_at,
         unlock_code_reset_requested_at = rotated_at
   where id = target_team_id;

  delete from public.unlock_verification_attempts where team_id = target_team_id;
  delete from public.protected_action_grants where team_id = target_team_id;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
  )
  values (
    actor_user_id, target_team_id, 'unlock_code.reset_prepared', 'success',
    'team', target_team_id::text, jsonb_build_object('reason', reset_reason, 'recipientCount', jsonb_array_length(recipients))
  );

  return jsonb_build_object(
    'teamId', target_team_id,
    'teamName', target_team.name,
    'unlockCode', generated_code,
    'recipients', recipients,
    'reason', reset_reason
  );
end;
$$;

revoke all on function public.prepare_team_invite_as_service(uuid,uuid,text,text) from public, anon, authenticated;
revoke all on function public.prepare_team_invite_resend_as_service(uuid,uuid) from public, anon, authenticated;
revoke all on function public.prepare_unlock_reset_as_service(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.prepare_team_invite_as_service(uuid,uuid,text,text) to service_role;
grant execute on function public.prepare_team_invite_resend_as_service(uuid,uuid) to service_role;
grant execute on function public.prepare_unlock_reset_as_service(uuid,uuid,text) to service_role;

