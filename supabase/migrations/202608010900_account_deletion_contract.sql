create table if not exists public.sports (
  key text primary key check (key ~ '^[a-z0-9_]{2,40}$'),
  display_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.sport_anonymous_alias_terms (
  sport_key text not null references public.sports(key) on delete cascade,
  term_kind text not null check (term_kind in ('adjective', 'noun')),
  term text not null check (length(btrim(term)) between 2 and 40),
  primary key (sport_key, term_kind, term)
);

insert into public.sports (key, display_name)
values ('pool', 'Pool'), ('generic_team', 'Team sport')
on conflict (key) do nothing;

insert into public.sport_anonymous_alias_terms (sport_key, term_kind, term)
values
  ('pool', 'adjective', 'Chalky'),
  ('pool', 'adjective', 'Lucky'),
  ('pool', 'adjective', 'Mysterious'),
  ('pool', 'adjective', 'Sneaky'),
  ('pool', 'adjective', 'Tactical'),
  ('pool', 'adjective', 'Wobbly'),
  ('pool', 'noun', 'Bank Shot'),
  ('pool', 'noun', 'Cue'),
  ('pool', 'noun', 'Eight Ball'),
  ('pool', 'noun', 'Pocket'),
  ('pool', 'noun', 'Rack'),
  ('pool', 'noun', 'Side Spin'),
  ('generic_team', 'adjective', 'Elusive'),
  ('generic_team', 'adjective', 'Legendary'),
  ('generic_team', 'adjective', 'Mighty'),
  ('generic_team', 'adjective', 'Secret'),
  ('generic_team', 'noun', 'Benchwarmer'),
  ('generic_team', 'noun', 'Maverick'),
  ('generic_team', 'noun', 'Substitute'),
  ('generic_team', 'noun', 'Wildcard')
on conflict do nothing;

alter table public.teams
  add column if not exists sport_key text not null default 'pool'
  references public.sports(key);

alter table public.sports enable row level security;
alter table public.sport_anonymous_alias_terms enable row level security;

drop policy if exists "authenticated users can read sports" on public.sports;
create policy "authenticated users can read sports" on public.sports
for select to authenticated using (true);
drop policy if exists "authenticated users can read alias terms" on public.sport_anonymous_alias_terms;
create policy "authenticated users can read alias terms" on public.sport_anonymous_alias_terms
for select to authenticated using (true);

create or replace function public.generate_team_anonymous_alias(target_team_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_sport text;
  adjective text;
  noun text;
  candidate text;
  attempt integer := 0;
begin
  select coalesce(t.sport_key, 'generic_team')
    into selected_sport
    from public.teams t
   where t.id = target_team_id;
  if selected_sport is null then raise exception 'Team not found'; end if;

  loop
    attempt := attempt + 1;
    select a.term into adjective
      from public.sport_anonymous_alias_terms a
     where a.sport_key in (selected_sport, 'generic_team')
       and a.term_kind = 'adjective'
     order by case when a.sport_key = selected_sport then 0 else 1 end,
              extensions.gen_random_bytes(4)
     limit 1;
    select n.term into noun
      from public.sport_anonymous_alias_terms n
     where n.sport_key in (selected_sport, 'generic_team')
       and n.term_kind = 'noun'
     order by case when n.sport_key = selected_sport then 0 else 1 end,
              extensions.gen_random_bytes(4)
     limit 1;
    candidate := adjective || ' ' || noun;

    exit when attempt >= 20 or not exists (
      select 1
        from public.fines f join public.matches m on m.id = f.match_id
       where m.team_id = target_team_id and lower(f.player_name) = lower(candidate)
      union all
      select 1
        from public.subs s join public.matches m on m.id = s.match_id
       where m.team_id = target_team_id and lower(s.player_name) = lower(candidate)
    );
  end loop;
  return candidate;
end;
$$;

create or replace function public.account_deletion_preflight()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_player_id uuid := public.current_player_id();
  blockers jsonb;
  solo_teams jsonb;
  fine_count integer;
  sub_count integer;
begin
  if auth.uid() is null or actor_player_id is null then
    raise exception 'Authenticated player profile required';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'teamId', t.id,
    'teamName', t.name,
    'otherActiveMembers', x.other_active_members
  ) order by t.name), '[]'::jsonb)
    into blockers
    from public.team_memberships mine
    join public.teams t on t.id = mine.team_id
    cross join lateral (
      select count(*)::integer as other_active_members
        from public.team_memberships other
       where other.team_id = mine.team_id
         and other.status = 'active'
         and other.player_id <> actor_player_id
    ) x
   where mine.player_id = actor_player_id
     and mine.status = 'active'
     and mine.role = 'captain'
     and x.other_active_members > 0;

  select coalesce(jsonb_agg(jsonb_build_object('teamId', t.id, 'teamName', t.name) order by t.name), '[]'::jsonb)
    into solo_teams
    from public.team_memberships mine
    join public.teams t on t.id = mine.team_id
   where mine.player_id = actor_player_id
     and mine.status = 'active'
     and mine.role = 'captain'
     and not exists (
       select 1 from public.team_memberships other
        where other.team_id = mine.team_id
          and other.status = 'active'
          and other.player_id <> actor_player_id
     );

  select count(*)::integer into fine_count
    from public.fines f join public.matches m on m.id = f.match_id
   where f.player_id = actor_player_id;
  select count(*)::integer into sub_count
    from public.subs s join public.matches m on m.id = s.match_id
   where s.player_id = actor_player_id;

  return jsonb_build_object(
    'email', lower(coalesce(auth.jwt()->>'email', '')),
    'captaincyBlockers', blockers,
    'teamsDeletedWithAccount', solo_teams,
    'historicalFineCount', fine_count,
    'historicalSubCount', sub_count,
    'deletionIsImmediate', true,
    'historicalAliasPolicy', 'sport_aware_team_specific'
  );
end;
$$;

create or replace function public.delete_current_account()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid := auth.uid();
  actor_player_id uuid := public.current_player_id();
  actor_email text := lower(coalesce(auth.jwt()->>'email', ''));
  authenticated_at timestamptz;
  blocked_teams text;
  team_record record;
  anonymous_alias text;
  deleted_team_count integer := 0;
  anonymised_fines integer := 0;
  anonymised_subs integer := 0;
  affected integer;
begin
  if actor_user_id is null or actor_player_id is null then
    raise exception 'Authenticated player profile required';
  end if;
  begin
    authenticated_at := to_timestamp((auth.jwt()->>'iat')::double precision);
  exception when others then
    raise exception 'Recent authentication required';
  end;
  if authenticated_at is null or authenticated_at < now() - interval '10 minutes' then
    raise exception 'Recent authentication required';
  end if;

  perform 1 from public.players where id = actor_player_id for update;
  select string_agg(t.name, ', ' order by t.name)
    into blocked_teams
    from public.team_memberships mine
    join public.teams t on t.id = mine.team_id
   where mine.player_id = actor_player_id
     and mine.status = 'active'
     and mine.role = 'captain'
     and exists (
       select 1 from public.team_memberships other
        where other.team_id = mine.team_id
          and other.status = 'active'
          and other.player_id <> actor_player_id
     );
  if blocked_teams is not null then
    raise exception 'Transfer captaincy before deleting your account: %', blocked_teams;
  end if;

  for team_record in
    select t.id
      from public.team_memberships mine
      join public.teams t on t.id = mine.team_id
     where mine.player_id = actor_player_id
       and mine.status = 'active'
       and mine.role = 'captain'
       and not exists (
         select 1 from public.team_memberships other
          where other.team_id = mine.team_id
            and other.status = 'active'
            and other.player_id <> actor_player_id
       )
     for update of t
  loop
    delete from public.teams where id = team_record.id;
    deleted_team_count := deleted_team_count + 1;
  end loop;

  for team_record in
    select distinct m.team_id
      from public.matches m
      left join public.fines f on f.match_id = m.id and f.player_id = actor_player_id
      left join public.subs s on s.match_id = m.id and s.player_id = actor_player_id
     where f.id is not null or s.id is not null
  loop
    anonymous_alias := public.generate_team_anonymous_alias(team_record.team_id);
    update public.fines f
       set player_name = anonymous_alias
      from public.matches m
     where f.match_id = m.id
       and m.team_id = team_record.team_id
       and f.player_id = actor_player_id;
    get diagnostics affected = row_count;
    anonymised_fines := anonymised_fines + affected;
    update public.subs s
       set player_name = anonymous_alias
      from public.matches m
     where s.match_id = m.id
       and m.team_id = team_record.team_id
       and s.player_id = actor_player_id;
    get diagnostics affected = row_count;
    anonymised_subs := anonymised_subs + affected;
  end loop;

  delete from public.team_invites
   where player_id = actor_player_id
      or (actor_email <> '' and lower(email) = actor_email);
  delete from public.players where id = actor_player_id;
  delete from auth.users where id = actor_user_id;

  return jsonb_build_object(
    'success', true,
    'deletedTeamCount', deleted_team_count,
    'anonymisedFineCount', anonymised_fines,
    'anonymisedSubCount', anonymised_subs
  );
end;
$$;

revoke all on function public.generate_team_anonymous_alias(uuid) from public, anon, authenticated;
revoke all on function public.account_deletion_preflight() from public, anon;
grant execute on function public.account_deletion_preflight() to authenticated;
revoke all on function public.delete_current_account() from public, anon;
grant execute on function public.delete_current_account() to authenticated;
notify pgrst, 'reload schema';
