create or replace function public.grant_team_season_access(
  operation_id uuid, target_team_id uuid, target_season_id uuid,
  grant_state public.entitlement_state, grant_source text,
  valid_from timestamptz, valid_until timestamptz, reason text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare definition_id uuid; existing jsonb; result jsonb; input_hash text;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if grant_state not in ('trial', 'complimentary') or grant_source not in ('trial', 'complimentary', 'correction') then raise exception 'Unsupported administrative grant'; end if;
  if valid_until <= valid_from or reason is null or length(btrim(reason)) < 8 then raise exception 'Valid period and reason are required'; end if;
  if not exists (select 1 from public.seasons where id = target_season_id and team_id = target_team_id) then raise exception 'Team season not found'; end if;
  input_hash := encode(extensions.digest(concat_ws('|', target_team_id, target_season_id, grant_state, grant_source, valid_from, valid_until, reason), 'sha256'), 'hex');
  select op.response into existing from public.commercial_operations op where op.operation_id = grant_team_season_access.operation_id and op.completed_at is not null;
  if existing is not null then
    if (select op.request_hash from public.commercial_operations op where op.operation_id = grant_team_season_access.operation_id) <> input_hash then raise exception 'Operation key was reused with different input'; end if;
    return existing;
  end if;
  insert into public.commercial_operations (operation_id, operation_type, actor_user_id, request_hash)
  values (operation_id, 'grant_team_season_access', auth.uid(), input_hash) on conflict do nothing;
  if not found then raise exception 'Operation is already in progress'; end if;
  select id into definition_id from public.entitlement_definitions where code = 'fines-team-standard' and state = 'published' order by version desc limit 1;
  insert into public.team_season_entitlements (team_id, season_id, entitlement_definition_id, state, valid_from, valid_until, source, source_reference, granted_by)
  values (target_team_id, target_season_id, definition_id, grant_state, valid_from, valid_until, grant_source, 'admin:' || operation_id, auth.uid());
  result := jsonb_build_object('success', true, 'teamId', target_team_id, 'seasonId', target_season_id, 'state', grant_state, 'validUntil', valid_until);
  update public.commercial_operations set response = result, completed_at = now() where commercial_operations.operation_id = grant_team_season_access.operation_id;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, after_data, reason)
  values (auth.uid(), 'entitlement.granted', 'team_season', concat(target_team_id, ':', target_season_id), result, btrim(reason));
  return result;
end $$;

revoke all on function public.grant_team_season_access(uuid, uuid, uuid, public.entitlement_state, text, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.grant_team_season_access(uuid, uuid, uuid, public.entitlement_state, text, timestamptz, timestamptz, text) to authenticated;
