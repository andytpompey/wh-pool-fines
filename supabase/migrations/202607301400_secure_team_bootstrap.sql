-- Secure, atomic team creation and join-code membership bootstrap.
-- These operations must not depend on broad table policies.

create or replace function public.create_team_with_captain(
  team_name text,
  requested_join_code text default null
)
returns public.teams
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

  select p.id
    into actor_player_id
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

  return created_team;
end;
$$;

create or replace function public.join_team_by_code(requested_join_code text)
returns public.teams
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

  select p.id
    into actor_player_id
    from public.players p
   where p.user_id = auth.uid()
   limit 1;

  if actor_player_id is null then
    raise exception 'Authenticated player profile not found';
  end if;

  select t.*
    into matched_team
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

  return matched_team;
end;
$$;

revoke all on function public.create_team_with_captain(text, text) from public;
revoke all on function public.create_team_with_captain(text, text) from anon;
grant execute on function public.create_team_with_captain(text, text) to authenticated;

revoke all on function public.join_team_by_code(text) from public;
revoke all on function public.join_team_by_code(text) from anon;
grant execute on function public.join_team_by_code(text) to authenticated;

drop policy if exists "allow all" on public.teams;
drop policy if exists "allow all" on public.team_memberships;
drop policy if exists "allow all" on public.team_invites;
drop policy if exists "team create" on public.teams;

