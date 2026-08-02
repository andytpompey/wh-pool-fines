-- Move unlock-code storage and verification behind authenticated server calls.

create table public.unlock_verification_attempts (
  team_id uuid not null references public.teams(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  attempt_count integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (team_id, actor_user_id)
);

create table public.protected_action_grants (
  token uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index protected_action_grants_lookup_idx
  on public.protected_action_grants
  (token, team_id, actor_user_id, action, expires_at)
  where consumed_at is null;

alter table public.unlock_verification_attempts enable row level security;
alter table public.protected_action_grants enable row level security;

revoke all on public.unlock_verification_attempts from public, anon, authenticated;
revoke all on public.protected_action_grants from public, anon, authenticated;

create or replace function public.is_team_leader(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.team_memberships tm
     where tm.team_id = target_team_id
       and tm.player_id = public.current_player_id()
       and tm.status = 'active'
       and tm.role in ('captain', 'vice_captain')
  );
$$;

create or replace function public.set_team_unlock_code(
  target_team_id uuid,
  new_unlock_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  rotated_at timestamptz := now();
begin
  if auth.uid() is null or not public.is_admin_of_team(target_team_id)
     or public.is_platform_admin() then
    raise exception 'Only the team captain can set the unlock code';
  end if;

  if new_unlock_code is null or new_unlock_code !~ '^[0-9]{4,12}$' then
    raise exception 'Unlock code must contain 4 to 12 digits';
  end if;

  update public.teams
     set unlock_code_hash = extensions.crypt(
           new_unlock_code,
           extensions.gen_salt('bf', 12)
         ),
         unlock_code_salt = null,
         unlock_code_hash_algorithm = 'bcrypt',
         unlock_code_hash_iterations = 12,
         unlock_code_version = 2,
         unlock_code_reset_required = false,
         unlock_code_last_rotated_at = rotated_at,
         unlock_code_reset_requested_at = rotated_at
   where id = target_team_id;

  if not found then
    raise exception 'Team not found';
  end if;

  delete from public.unlock_verification_attempts
   where team_id = target_team_id;
  delete from public.protected_action_grants
   where team_id = target_team_id;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type,
    target_entity_id, payload
  )
  values (
    auth.uid(), target_team_id, 'unlock_code.set', 'success', 'team',
    target_team_id::text, jsonb_build_object('version', 2)
  );

  return jsonb_build_object(
    'teamId', target_team_id,
    'unlockCodeResetRequired', false,
    'unlockCodeLastRotatedAt', rotated_at
  );
end;
$$;

create or replace function public.verify_team_unlock_code(
  target_team_id uuid,
  protected_action text,
  supplied_unlock_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  stored_hash text;
  reset_required boolean;
  attempt_record public.unlock_verification_attempts;
  matched boolean := false;
  grant_token uuid;
  grant_expiry timestamptz;
  now_at timestamptz := now();
  allowed_actions constant text[] := array[
    'remove_team_member',
    'delete_match',
    'delete_fine_entry',
    'delete_fine_type',
    'delete_season',
    'unlock_match',
    'change_unlock_code'
  ];
begin
  if auth.uid() is null or not public.is_team_leader(target_team_id)
     or public.is_platform_admin() then
    return jsonb_build_object('authorized', false, 'reason', 'forbidden');
  end if;

  if protected_action is null or not (protected_action = any(allowed_actions)) then
    return jsonb_build_object('authorized', false, 'reason', 'unsupported_action');
  end if;

  insert into public.unlock_verification_attempts (
    team_id, actor_user_id, window_started_at, attempt_count, updated_at
  )
  values (target_team_id, auth.uid(), now_at, 0, now_at)
  on conflict (team_id, actor_user_id) do nothing;

  select *
    into attempt_record
    from public.unlock_verification_attempts
   where team_id = target_team_id
     and actor_user_id = auth.uid()
   for update;

  if attempt_record.locked_until is not null
     and attempt_record.locked_until > now_at then
    return jsonb_build_object(
      'authorized', false,
      'reason', 'rate_limited',
      'retryAt', attempt_record.locked_until
    );
  end if;

  if attempt_record.window_started_at < now_at - interval '5 minutes' then
    update public.unlock_verification_attempts
       set window_started_at = now_at,
           attempt_count = 0,
           locked_until = null,
           updated_at = now_at
     where team_id = target_team_id
       and actor_user_id = auth.uid();
    attempt_record.attempt_count := 0;
  end if;

  select t.unlock_code_hash, t.unlock_code_reset_required
    into stored_hash, reset_required
    from public.teams t
   where t.id = target_team_id;

  if stored_hash is not null
     and reset_required = false
     and supplied_unlock_code is not null then
    matched := extensions.crypt(supplied_unlock_code, stored_hash) = stored_hash;
  end if;

  if not matched then
    update public.unlock_verification_attempts
       set attempt_count = attempt_record.attempt_count + 1,
           locked_until = case
             when attempt_record.attempt_count + 1 >= 5
               then now_at + interval '5 minutes'
             else null
           end,
           updated_at = now_at
     where team_id = target_team_id
       and actor_user_id = auth.uid();

    insert into public.audit_logs (
      actor_user_id, team_id, action, outcome, target_entity_type,
      target_entity_id, payload
    )
    values (
      auth.uid(), target_team_id, 'unlock_code.verification', 'failure',
      'protected_action', protected_action,
      jsonb_build_object('reason', 'invalid_or_unavailable')
    );

    return jsonb_build_object('authorized', false, 'reason', 'invalid_code');
  end if;

  update public.unlock_verification_attempts
     set window_started_at = now_at,
         attempt_count = 0,
         locked_until = null,
         updated_at = now_at
   where team_id = target_team_id
     and actor_user_id = auth.uid();

  grant_expiry := now_at + interval '60 seconds';
  insert into public.protected_action_grants (
    team_id, actor_user_id, action, expires_at
  )
  values (target_team_id, auth.uid(), protected_action, grant_expiry)
  returning token into grant_token;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type,
    target_entity_id, payload
  )
  values (
    auth.uid(), target_team_id, 'unlock_code.verification', 'success',
    'protected_action', protected_action,
    jsonb_build_object('grantExpiresAt', grant_expiry)
  );

  return jsonb_build_object(
    'authorized', true,
    'grantToken', grant_token,
    'expiresAt', grant_expiry
  );
end;
$$;

create or replace function public.mark_team_unlock_reset_required(target_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_admin_of_team(target_team_id) then
    raise exception 'Captain or platform administrator access required';
  end if;

  update public.teams
     set unlock_code_hash = null,
         unlock_code_salt = null,
         unlock_code_reset_required = true,
         unlock_code_reset_requested_at = now()
   where id = target_team_id;

  if not found then
    raise exception 'Team not found';
  end if;

  delete from public.protected_action_grants where team_id = target_team_id;

  return jsonb_build_object(
    'teamId', target_team_id,
    'unlockCodeResetRequired', true
  );
end;
$$;

revoke all on function public.is_team_leader(uuid) from public, anon;
revoke all on function public.set_team_unlock_code(uuid, text) from public, anon;
revoke all on function public.verify_team_unlock_code(uuid, text, text) from public, anon;
revoke all on function public.mark_team_unlock_reset_required(uuid) from public, anon;
grant execute on function public.is_team_leader(uuid) to authenticated;
grant execute on function public.set_team_unlock_code(uuid, text) to authenticated;
grant execute on function public.verify_team_unlock_code(uuid, text, text) to authenticated;
grant execute on function public.mark_team_unlock_reset_required(uuid) to authenticated;

-- Legacy PBKDF2 values cannot be verified safely in PostgreSQL. Require a
-- captain-controlled rotation when this migration eventually reaches existing
-- environments.
update public.teams
   set unlock_code_hash = null,
       unlock_code_salt = null,
       unlock_code_reset_required = true
 where unlock_code_hash is not null
   and unlock_code_version < 2;

revoke select, update on public.teams from authenticated;
grant select (
  id, name, join_code, created_by, created_at,
  unlock_code_last_rotated_at, unlock_code_reset_required,
  unlock_code_reset_requested_at, subs_enabled, drivers_void_subs, sub_amount,
  logo_url, rackem_import_enabled, rackem_league_slug, rackem_league_name,
  rackem_team_id, rackem_team_name, rackem_team_url
) on public.teams to authenticated;
grant update (
  name, join_code, subs_enabled, drivers_void_subs, sub_amount, logo_url,
  rackem_import_enabled, rackem_league_slug, rackem_league_name,
  rackem_team_id, rackem_team_name, rackem_team_url
) on public.teams to authenticated;

drop function public.create_team_with_captain(text, text);
create function public.create_team_with_captain(
  team_name text,
  requested_join_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_player_id uuid;
  created_team public.teams;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if team_name is null or btrim(team_name) = '' then
    raise exception 'Team name is required';
  end if;

  select p.id into actor_player_id
    from public.players p
   where p.user_id = auth.uid()
   limit 1;
  if actor_player_id is null then
    raise exception 'Authenticated player profile not found';
  end if;

  insert into public.teams (name, created_by, join_code)
  values (
    btrim(team_name),
    actor_player_id,
    nullif(upper(btrim(requested_join_code)), '')
  )
  returning * into created_team;

  insert into public.team_memberships (team_id, player_id, role, status)
  values (created_team.id, actor_player_id, 'captain', 'active');

  return to_jsonb(created_team)
    - 'unlock_code_hash'
    - 'unlock_code_salt'
    - 'unlock_code_hash_algorithm'
    - 'unlock_code_hash_iterations'
    - 'unlock_code_version';
end;
$$;

drop function public.join_team_by_code(text);
create function public.join_team_by_code(requested_join_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_player_id uuid;
  matched_team public.teams;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if requested_join_code is null or btrim(requested_join_code) = '' then
    raise exception 'Join code is required';
  end if;

  select p.id into actor_player_id
    from public.players p
   where p.user_id = auth.uid()
   limit 1;
  if actor_player_id is null then
    raise exception 'Authenticated player profile not found';
  end if;

  select t.* into matched_team
    from public.teams t
   where t.join_code = upper(btrim(requested_join_code))
   limit 1;
  if matched_team.id is null then
    raise exception 'Invalid join code';
  end if;

  insert into public.team_memberships (team_id, player_id, role, status)
  values (matched_team.id, actor_player_id, 'member', 'active')
  on conflict (team_id, player_id)
  do update set
    status = 'active',
    role = case
      when public.team_memberships.role in ('captain', 'vice_captain')
        then public.team_memberships.role
      else 'member'
    end;

  return to_jsonb(matched_team)
    - 'unlock_code_hash'
    - 'unlock_code_salt'
    - 'unlock_code_hash_algorithm'
    - 'unlock_code_hash_iterations'
    - 'unlock_code_version';
end;
$$;

revoke all on function public.create_team_with_captain(text, text) from public, anon;
revoke all on function public.join_team_by_code(text) from public, anon;
grant execute on function public.create_team_with_captain(text, text) to authenticated;
grant execute on function public.join_team_by_code(text) to authenticated;
