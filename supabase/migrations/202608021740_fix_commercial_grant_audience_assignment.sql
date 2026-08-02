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
  if length(btrim(audience_name)) < 3 or $3 not in ('league', 'division') or
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
       set name = btrim(audience_name), audience_type = $3, parent_audience_id = $4, updated_at = now()
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
