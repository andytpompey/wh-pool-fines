alter table public.matches
  add column if not exists edit_version bigint not null default 1;

create or replace function public.bump_match_edit_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.edit_version = old.edit_version then
    new.edit_version := old.edit_version + 1;
  end if;
  return new;
end;
$$;

drop trigger if exists matches_bump_edit_version on public.matches;
create trigger matches_bump_edit_version
before update on public.matches
for each row execute function public.bump_match_edit_version();

create or replace function public.bump_parent_match_edit_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_match_id uuid := coalesce(new.match_id, old.match_id);
begin
  update public.matches
     set edit_version = edit_version + 1
   where id = affected_match_id;
  return coalesce(new, old);
end;
$$;

drop trigger if exists match_players_bump_match_version on public.match_players;
create trigger match_players_bump_match_version
after insert or update or delete on public.match_players
for each row execute function public.bump_parent_match_edit_version();
drop trigger if exists fines_bump_match_version on public.fines;
create trigger fines_bump_match_version
after insert or update or delete on public.fines
for each row execute function public.bump_parent_match_edit_version();
drop trigger if exists subs_bump_match_version on public.subs;
create trigger subs_bump_match_version
after insert or update or delete on public.subs
for each row execute function public.bump_parent_match_edit_version();

create or replace function public.update_match_fixture(
  operation_id uuid,
  target_match_id uuid,
  expected_version bigint,
  fixture_date date,
  fixture_opponent text,
  fixture_venue text,
  fixture_season_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_match public.matches;
  team_settings public.teams;
  existing_response jsonb;
  final_version bigint;
  result jsonb;
begin
  if auth.uid() is null or operation_id is null or expected_version is null then
    raise exception 'Authentication, operation, and expected version are required';
  end if;

  select io.response into existing_response
    from public.idempotent_operations io
   where io.actor_user_id = auth.uid()
     and io.operation_id = update_match_fixture.operation_id
     and io.operation_type = 'update_match_fixture'
     and io.completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  select m.* into target_match from public.matches m
   where m.id = target_match_id for update;
  if target_match.id is null or target_match.submitted
     or not public.can_manage_team_operations(target_match.team_id) then
    raise exception 'Editable draft match leadership access required';
  end if;
  if target_match.edit_version <> expected_version then
    raise exception 'Match changed elsewhere; refresh before saving';
  end if;
  if fixture_date is null or fixture_opponent is null or btrim(fixture_opponent) = '' then
    raise exception 'Date and opponent are required';
  end if;
  if fixture_venue not in ('home', 'away') then
    raise exception 'Venue must be home or away';
  end if;
  if fixture_season_id is not null and not exists (
    select 1 from public.seasons s
     where s.id = fixture_season_id and s.team_id = target_match.team_id
  ) then raise exception 'Season is not available for this team'; end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'update_match_fixture') on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  select t.* into team_settings from public.teams t where t.id = target_match.team_id;
  update public.matches
     set date = fixture_date,
         opponent = btrim(fixture_opponent),
         venue = fixture_venue,
         season_id = fixture_season_id
   where id = target_match_id;

  if fixture_venue = 'home' then
    update public.match_players set is_driver = false where match_id = target_match_id and is_driver;
  end if;

  delete from public.subs s
   where s.match_id = target_match_id
     and (
       not team_settings.subs_enabled
       or not exists (
         select 1 from public.match_players mp
          where mp.match_id = target_match_id and mp.player_id = s.player_id
            and not (
              fixture_venue = 'away'
              and team_settings.drivers_void_subs
              and mp.is_driver
            )
       )
     );

  if team_settings.subs_enabled then
    insert into public.subs (match_id, player_id, player_name, amount, paid)
    select target_match_id, p.id, coalesce(p.display_name, p.name), team_settings.sub_amount, false
      from public.match_players mp
      join public.players p on p.id = mp.player_id
     where mp.match_id = target_match_id
       and not (
         fixture_venue = 'away'
         and team_settings.drivers_void_subs
         and mp.is_driver
       )
       and not exists (
         select 1 from public.subs s
          where s.match_id = target_match_id and s.player_id = mp.player_id
       );
  end if;

  select edit_version into final_version from public.matches where id = target_match_id;
  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
  ) values (
    auth.uid(), target_match.team_id, 'match.fixture.updated', 'success', 'match', target_match_id::text,
    jsonb_build_object('operationId', operation_id, 'previousVersion', expected_version, 'editVersion', final_version)
  );
  result := jsonb_build_object(
    'success', true, 'operationId', operation_id,
    'matchId', target_match_id, 'editVersion', final_version
  );
  update public.idempotent_operations set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = update_match_fixture.operation_id;
  return result;
end;
$$;

revoke all on function public.update_match_fixture(uuid, uuid, bigint, date, text, text, uuid) from public, anon;
grant execute on function public.update_match_fixture(uuid, uuid, bigint, date, text, text, uuid) to authenticated;
revoke all on function public.bump_match_edit_version() from public, anon, authenticated;
revoke all on function public.bump_parent_match_edit_version() from public, anon, authenticated;
notify pgrst, 'reload schema';
