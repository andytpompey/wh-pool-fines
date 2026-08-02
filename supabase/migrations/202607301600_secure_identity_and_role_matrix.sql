-- Server-owned identity linking and role-aware authorization.

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.app_users au
     where au.id = auth.uid()
       and au.is_platform_admin = true
  );
$$;

create or replace function public.current_player_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
    from public.players p
   where p.user_id = auth.uid()
   order by p.created_at asc
   limit 1;
$$;

create or replace function public.current_player_id_for_auth_user()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_player_id();
$$;

create or replace function public.is_member_of_team(target_team_id uuid)
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
       and tm.status = 'active'
       and tm.player_id = public.current_player_id()
  );
$$;

create or replace function public.is_admin_of_team(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
      or exists (
        select 1
          from public.team_memberships tm
         where tm.team_id = target_team_id
           and tm.status = 'active'
           and tm.role = 'captain'
           and tm.player_id = public.current_player_id()
      );
$$;

create or replace function public.can_manage_team_operations(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
      or exists (
        select 1
          from public.team_memberships tm
         where tm.team_id = target_team_id
           and tm.status = 'active'
           and tm.role in ('captain', 'vice_captain')
           and tm.player_id = public.current_player_id()
      );
$$;

create or replace function public.can_view_team(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
      or public.is_member_of_team(target_team_id);
$$;

create or replace function public.shares_team_with_player(target_player_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
      or target_player_id = public.current_player_id()
      or exists (
        select 1
          from public.team_memberships mine
          join public.team_memberships theirs
            on theirs.team_id = mine.team_id
           and theirs.status = 'active'
         where mine.player_id = public.current_player_id()
           and mine.status = 'active'
           and theirs.player_id = target_player_id
      );
$$;

create or replace function public.ensure_current_player(
  profile_display_name text default null,
  profile_mobile text default null,
  profile_preferred_auth_method text default null
)
returns public.players
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid := auth.uid();
  verified_email text;
  verified_phone text;
  resolved_player public.players;
  resolved_name text;
  resolved_method text;
begin
  if actor_user_id is null then
    raise exception 'Authentication required';
  end if;

  select lower(u.email), u.phone
    into verified_email, verified_phone
    from auth.users u
   where u.id = actor_user_id;

  if verified_email is null and verified_phone is null then
    raise exception 'A verified email or phone identity is required';
  end if;

  select p.*
    into resolved_player
    from public.players p
   where p.user_id = actor_user_id
   limit 1;

  if resolved_player.id is not null then
    return resolved_player;
  end if;

  if verified_email is not null then
    select p.*
      into resolved_player
      from public.players p
     where lower(p.email) = verified_email
       and p.user_id is null
     limit 1
     for update;
  end if;

  if resolved_player.id is null and verified_phone is not null then
    select p.*
      into resolved_player
      from public.players p
     where p.mobile = verified_phone
       and p.user_id is null
     limit 1
     for update;
  end if;

  resolved_name := coalesce(
    nullif(btrim(profile_display_name), ''),
    nullif(split_part(coalesce(verified_email, ''), '@', 1), ''),
    'Player'
  );
  resolved_method := case
    when profile_preferred_auth_method = 'whatsapp' and verified_phone is not null
      then 'whatsapp'
    else 'email'
  end;

  if resolved_player.id is not null then
    update public.players
       set user_id = actor_user_id,
           auth_user_id = actor_user_id,
           display_name = coalesce(nullif(display_name, ''), resolved_name),
           name = coalesce(nullif(name, ''), resolved_name),
           mobile = coalesce(mobile, verified_phone),
           preferred_auth_method = coalesce(preferred_auth_method, resolved_method)
     where id = resolved_player.id
       and user_id is null
     returning * into resolved_player;

    if resolved_player.id is null then
      raise exception 'Player identity was linked concurrently; sign in again';
    end if;

    return resolved_player;
  end if;

  insert into public.players (
    name,
    display_name,
    email,
    mobile,
    preferred_auth_method,
    user_id,
    auth_user_id,
    receive_team_notifications
  )
  values (
    resolved_name,
    resolved_name,
    verified_email,
    coalesce(verified_phone, nullif(btrim(profile_mobile), '')),
    resolved_method,
    actor_user_id,
    actor_user_id,
    true
  )
  returning * into resolved_player;

  return resolved_player;
exception
  when unique_violation then
    raise exception 'This verified identity is already linked to another account';
end;
$$;

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

do $$
declare
  function_signature text;
begin
  foreach function_signature in array array[
    'public.is_platform_admin()',
    'public.current_player_id()',
    'public.current_player_id_for_auth_user()',
    'public.is_member_of_team(uuid)',
    'public.is_admin_of_team(uuid)',
    'public.can_manage_team_operations(uuid)',
    'public.can_view_team(uuid)',
    'public.shares_team_with_player(uuid)',
    'public.ensure_current_player(text,text,text)'
  ]
  loop
    execute format('revoke all on function %s from public', function_signature);
    execute format('revoke all on function %s from anon', function_signature);
    execute format('grant execute on function %s to authenticated', function_signature);
  end loop;
end $$;

drop policy if exists "players auth lookup" on public.players;
drop policy if exists "players registration insert" on public.players;
drop policy if exists "own profile" on public.players;

create policy "players visible to authorised users"
on public.players for select to authenticated
using (public.shares_team_with_player(id));

drop policy if exists "app_users self" on public.app_users;
create policy "app users select self"
on public.app_users for select to authenticated
using (id = auth.uid());
create policy "app users register self"
on public.app_users for insert to authenticated
with check (id = auth.uid() and is_platform_admin = false);

drop policy if exists "team scoped read" on public.teams;
create policy "team scoped read"
on public.teams for select to authenticated
using (public.can_view_team(id));

drop policy if exists "team scoped read" on public.team_memberships;
create policy "team scoped read"
on public.team_memberships for select to authenticated
using (public.can_view_team(team_id));

drop policy if exists "team scoped read" on public.team_invites;
create policy "team scoped read"
on public.team_invites for select to authenticated
using (public.can_view_team(team_id));

drop policy if exists "team scoped write" on public.fine_types;
create policy "team scoped write"
on public.fine_types for all to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.seasons;
create policy "team scoped write"
on public.seasons for all to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.matches;
create policy "team scoped write"
on public.matches for all to authenticated
using (public.can_manage_team_operations(team_id))
with check (public.can_manage_team_operations(team_id));

drop policy if exists "team scoped write" on public.match_players;
create policy "team scoped write"
on public.match_players for all to authenticated
using (
  exists (
    select 1 from public.matches m
     where m.id = match_players.match_id
       and public.can_manage_team_operations(m.team_id)
  )
)
with check (
  exists (
    select 1 from public.matches m
     where m.id = match_players.match_id
       and public.can_manage_team_operations(m.team_id)
  )
);

drop policy if exists "team scoped write" on public.fines;
create policy "team scoped write"
on public.fines for all to authenticated
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
create policy "team scoped write"
on public.subs for all to authenticated
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
