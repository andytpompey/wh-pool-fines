-- A paid playing cycle is the commercial boundary. Multiple League, Cup and
-- Plate season records may belong to the same cycle and must not be charged
-- separately.

create table public.team_playing_cycles (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete restrict,
  name text not null,
  sport text not null default 'pool',
  starts_on date,
  ends_on date,
  status text not null default 'planned' check (status in ('planned', 'active', 'completed', 'abandoned', 'cancelled')),
  source text not null default 'manual' check (source in ('manual', 'rackem', 'migration')),
  source_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or starts_on is not null),
  check (ends_on is null or ends_on >= starts_on),
  unique (team_id, name, sport)
);

alter table public.seasons add column playing_cycle_id uuid references public.team_playing_cycles(id) on delete restrict;

insert into public.team_playing_cycles (id, team_id, name, sport, status, source, source_reference)
select s.id, s.team_id, s.name, 'pool', 'active', 'migration', s.id::text
from public.seasons s
on conflict (id) do nothing;

update public.seasons set playing_cycle_id = id where playing_cycle_id is null;
alter table public.seasons alter column playing_cycle_id set not null;

alter table public.team_season_entitlements add column playing_cycle_id uuid references public.team_playing_cycles(id) on delete restrict;
update public.team_season_entitlements e set playing_cycle_id = s.playing_cycle_id from public.seasons s where s.id = e.season_id;
alter table public.team_season_entitlements alter column playing_cycle_id set not null;
alter table public.team_season_entitlements alter column season_id drop not null;
alter table public.team_season_entitlements add constraint one_entitlement_per_cycle_source
  unique nulls not distinct (team_id, playing_cycle_id, entitlement_definition_id, subscription_id);

alter table public.commercial_subscriptions add column playing_cycle_id uuid references public.team_playing_cycles(id) on delete restrict;
update public.commercial_subscriptions cs set playing_cycle_id = s.playing_cycle_id from public.seasons s where s.id = cs.season_id;

create index team_playing_cycles_lookup on public.team_playing_cycles (team_id, status, starts_on, ends_on);
create index entitlement_cycle_lookup on public.team_season_entitlements (team_id, playing_cycle_id, state, valid_until);

alter table public.team_playing_cycles enable row level security;
create policy "team members read playing cycles" on public.team_playing_cycles for select to authenticated
  using (public.is_member_of_team(team_id) or public.is_platform_admin());
create policy "team leaders create playing cycles" on public.team_playing_cycles for insert to authenticated
  with check (public.can_manage_team_operations(team_id));
create policy "team leaders update playing cycles" on public.team_playing_cycles for update to authenticated
  using (public.can_manage_team_operations(team_id)) with check (public.can_manage_team_operations(team_id));
grant select, insert, update on public.team_playing_cycles to authenticated;

create or replace function public.assign_default_playing_cycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.playing_cycle_id is null then
    insert into public.team_playing_cycles (id, team_id, name, sport, status, source, source_reference)
    values (new.id, new.team_id, new.name, 'pool', 'planned', case when new.source = 'rackem' then 'rackem' else 'manual' end, new.source_season_team_id)
    on conflict (id) do nothing;
    new.playing_cycle_id := new.id;
  end if;
  if not exists (select 1 from public.team_playing_cycles c where c.id = new.playing_cycle_id and c.team_id = new.team_id) then
    raise exception 'Playing cycle must belong to the same team';
  end if;
  return new;
end $$;

create trigger seasons_assign_playing_cycle before insert or update of playing_cycle_id, team_id on public.seasons
for each row execute function public.assign_default_playing_cycle();

create or replace function public.current_team_cycle_entitlement(target_team_id uuid, target_playing_cycle_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object(
      'id', e.id,
      'state', case
        when e.revoked_at is not null then 'revoked'
        when now() <= e.valid_until then e.state::text
        when e.grace_until is not null and now() <= e.grace_until then 'grace'
        else 'expired'
      end,
      'validFrom', e.valid_from, 'validUntil', e.valid_until,
      'graceUntil', e.grace_until, 'source', e.source,
      'capabilities', d.capabilities
    )
    from public.team_season_entitlements e
    join public.entitlement_definitions d on d.id = e.entitlement_definition_id
    where e.team_id = target_team_id and e.playing_cycle_id = target_playing_cycle_id
      and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
    order by (e.revoked_at is null) desc, e.valid_until desc limit 1
  ), jsonb_build_object('state', 'missing', 'capabilities', '{}'::jsonb));
$$;

create or replace function public.current_team_season_entitlement(target_team_id uuid, target_season_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.current_team_cycle_entitlement(target_team_id, s.playing_cycle_id)
  from public.seasons s where s.id = target_season_id and s.team_id = target_team_id;
$$;

create or replace function public.has_team_cycle_capability(target_team_id uuid, target_playing_cycle_id uuid, capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.team_season_entitlements e
    join public.entitlement_definitions d on d.id = e.entitlement_definition_id
    where e.team_id = target_team_id and e.playing_cycle_id = target_playing_cycle_id
      and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
      and e.revoked_at is null and now() >= e.valid_from
      and now() <= coalesce(e.grace_until, e.valid_until)
      and e.state in ('trial', 'active', 'grace', 'complimentary')
      and coalesce((d.capabilities ->> capability)::boolean, false)
  );
$$;

create or replace function public.has_team_season_capability(target_team_id uuid, target_season_id uuid, capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.has_team_cycle_capability(target_team_id, s.playing_cycle_id, capability), false)
  from public.seasons s where s.id = target_season_id and s.team_id = target_team_id;
$$;

revoke all on function public.current_team_cycle_entitlement(uuid, uuid) from public, anon;
grant execute on function public.current_team_cycle_entitlement(uuid, uuid) to authenticated;
revoke all on function public.has_team_cycle_capability(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.has_team_season_capability(uuid, uuid, text) from public, anon, authenticated;

comment on table public.team_playing_cycles is 'Commercial boundary covering one normal team playing cycle; League, Cup and Plate season rows may share it.';
