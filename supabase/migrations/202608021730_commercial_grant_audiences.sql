create table public.commercial_grant_audiences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  audience_type text not null check (audience_type in ('league', 'division')),
  parent_audience_id uuid references public.commercial_grant_audiences(id),
  state text not null default 'active' check (state in ('active', 'archived')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((audience_type = 'league' and parent_audience_id is null) or
         (audience_type = 'division' and parent_audience_id is not null))
);

create unique index commercial_grant_audiences_active_name
  on public.commercial_grant_audiences (lower(name), audience_type, coalesce(parent_audience_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where state = 'active';

create table public.commercial_grant_audience_cycles (
  audience_id uuid not null references public.commercial_grant_audiences(id) on delete cascade,
  playing_cycle_id uuid not null references public.team_playing_cycles(id),
  added_at timestamptz not null default now(),
  primary key (audience_id, playing_cycle_id)
);

alter table public.commercial_grant_audiences enable row level security;
alter table public.commercial_grant_audience_cycles enable row level security;
revoke all on public.commercial_grant_audiences, public.commercial_grant_audience_cycles from anon, authenticated;

create or replace function public.save_commercial_grant_audience(
  target_audience_id uuid,
  audience_name text,
  audience_type text,
  parent_audience_id uuid,
  target_cycle_ids uuid[],
  reason text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  saved public.commercial_grant_audiences;
  before_record jsonb;
  distinct_cycle_count integer;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  select count(distinct cycle_id) into distinct_cycle_count from unnest(target_cycle_ids) cycle_id;
  if length(btrim(audience_name)) < 3 or audience_type not in ('league', 'division') or
     cardinality(target_cycle_ids) < 1 or cardinality(target_cycle_ids) > 500 or
     distinct_cycle_count <> cardinality(target_cycle_ids) or length(btrim(reason)) < 12 then
    raise exception 'Audience name, type, unique cycles and detailed reason are required';
  end if;
  if $3 = 'league' and $4 is not null then raise exception 'League audiences cannot have a parent'; end if;
  if $3 = 'division' and not exists (
    select 1 from public.commercial_grant_audiences a where a.id = $4 and a.audience_type = 'league' and a.state = 'active'
  ) then raise exception 'Division audiences require an active league audience'; end if;
  if (select count(*) from public.team_playing_cycles where id = any(target_cycle_ids)) <> cardinality(target_cycle_ids) then
    raise exception 'One or more playing cycles were not found';
  end if;

  if target_audience_id is null then
    insert into public.commercial_grant_audiences(name, audience_type, parent_audience_id, created_by)
    values (btrim(audience_name), $3, $4, auth.uid()) returning * into saved;
  else
    select to_jsonb(a) into before_record from public.commercial_grant_audiences a where a.id = target_audience_id for update;
    if before_record is null then raise exception 'Grant audience not found'; end if;
    update public.commercial_grant_audiences
       set name = btrim(audience_name), audience_type = $3,
           parent_audience_id = $4, updated_at = now()
     where id = target_audience_id returning * into saved;
    delete from public.commercial_grant_audience_cycles where audience_id = saved.id;
  end if;

  insert into public.commercial_grant_audience_cycles(audience_id, playing_cycle_id)
  select saved.id, cycle_id from unnest(target_cycle_ids) cycle_id;
  insert into public.commercial_audit_log(actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (auth.uid(), case when target_audience_id is null then 'grant_audience.created' else 'grant_audience.updated' end,
          'commercial_grant_audience', saved.id::text, before_record,
          to_jsonb(saved) || jsonb_build_object('playingCycleIds', target_cycle_ids), btrim(reason));
  return jsonb_build_object('id', saved.id, 'name', saved.name, 'audienceType', saved.audience_type,
                            'parentAudienceId', saved.parent_audience_id, 'playingCycleIds', target_cycle_ids);
end $$;

create or replace function public.get_commercial_grant_audiences() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when public.is_platform_admin() then coalesce(jsonb_agg(audience_row order by audience_row->>'audienceType', audience_row->>'name'), '[]'::jsonb) else null end
  from (
    select jsonb_build_object(
      'id', a.id, 'name', a.name, 'audienceType', a.audience_type, 'parentAudienceId', a.parent_audience_id,
      'playingCycleIds', coalesce(jsonb_agg(c.id order by t.name, c.name) filter (where c.id is not null), '[]'::jsonb),
      'teams', coalesce(jsonb_agg(jsonb_build_object('teamId', t.id, 'teamName', t.name, 'playingCycleId', c.id, 'cycleName', c.name)
                                  order by t.name, c.name) filter (where c.id is not null), '[]'::jsonb)
    ) audience_row
    from public.commercial_grant_audiences a
    left join public.commercial_grant_audience_cycles ac on ac.audience_id = a.id
    left join public.team_playing_cycles c on c.id = ac.playing_cycle_id
    left join public.teams t on t.id = c.team_id
    where a.state = 'active'
    group by a.id
  ) rows;
$$;

create or replace function public.grant_founding_audience_access(
  operation_id uuid,
  target_audience_id uuid,
  expected_cycle_ids uuid[],
  grant_state public.entitlement_state,
  valid_from timestamptz,
  valid_until timestamptz,
  agreed_price_minor integer,
  discount_minor integer,
  grant_owner uuid,
  reason text,
  preview_only boolean default true
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  audience public.commercial_grant_audiences;
  current_cycle_ids uuid[];
  expected_sorted uuid[];
  result jsonb;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  select * into audience from public.commercial_grant_audiences where id = target_audience_id and state = 'active';
  if audience.id is null then raise exception 'Active grant audience not found'; end if;
  select array_agg(playing_cycle_id order by playing_cycle_id) into current_cycle_ids
    from public.commercial_grant_audience_cycles where audience_id = audience.id;
  if cardinality(current_cycle_ids) < 1 then raise exception 'Grant audience has no playing cycles'; end if;
  if not preview_only then
    select array_agg(cycle_id order by cycle_id) into expected_sorted from unnest(expected_cycle_ids) cycle_id;
    if expected_sorted is distinct from current_cycle_ids then raise exception 'Grant audience changed since preview; preview again'; end if;
  end if;
  result := public.grant_founding_access_batch(operation_id, current_cycle_ids, grant_state, valid_from, valid_until,
                                               agreed_price_minor, discount_minor, grant_owner, reason, preview_only)
            || jsonb_build_object('audienceId', audience.id, 'audienceName', audience.name,
                                  'audienceType', audience.audience_type, 'audienceCycleIds', current_cycle_ids);
  if not preview_only then
    update public.commercial_operations set response = result where commercial_operations.operation_id = grant_founding_audience_access.operation_id;
    update public.commercial_audit_log set after_data = result
     where action = 'founding_access.batch_granted' and entity_id = operation_id::text;
  end if;
  return result;
end $$;

revoke all on function public.save_commercial_grant_audience(uuid,text,text,uuid,uuid[],text) from public, anon;
revoke all on function public.get_commercial_grant_audiences() from public, anon;
revoke all on function public.grant_founding_audience_access(uuid,uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,integer,integer,uuid,text,boolean) from public, anon;
grant execute on function public.save_commercial_grant_audience(uuid,text,text,uuid,uuid[],text) to authenticated;
grant execute on function public.get_commercial_grant_audiences() to authenticated;
grant execute on function public.grant_founding_audience_access(uuid,uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,integer,integer,uuid,text,boolean) to authenticated;
