create or replace function public.grant_team_cycle_access_batch(operation_id uuid,target_cycle_ids uuid[],grant_state public.entitlement_state,valid_from timestamptz,valid_until timestamptz,reason text,preview_only boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare input_hash text; existing jsonb; definition_id uuid; invalid_count integer; affected jsonb; result jsonb;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if grant_state not in ('trial','complimentary') or valid_until<=valid_from or cardinality(target_cycle_ids)=0 or length(btrim(reason))<8 then raise exception 'Valid cycles, period and reason are required'; end if;
 select count(*) into invalid_count from unnest(target_cycle_ids) as requested(cycle_id) left join public.team_playing_cycles c on c.id=requested.cycle_id where c.id is null;
 if invalid_count>0 then raise exception 'One or more playing cycles were not found'; end if;
 select jsonb_agg(jsonb_build_object('playingCycleId',c.id,'teamId',c.team_id,'name',c.name,'alreadyCovered',exists(select 1 from public.team_season_entitlements e where e.team_id=c.team_id and e.playing_cycle_id=c.id and e.revoked_at is null and now()<=coalesce(e.grace_until,e.valid_until)))) into affected from public.team_playing_cycles c where c.id=any(target_cycle_ids);
 if preview_only then return jsonb_build_object('preview',true,'cycles',coalesce(affected,'[]'::jsonb)); end if;
 input_hash:=encode(extensions.digest(concat_ws('|',array_to_string(target_cycle_ids,','),grant_state,valid_from,valid_until,reason),'sha256'),'hex');
 select response into existing from public.commercial_operations where commercial_operations.operation_id=grant_team_cycle_access_batch.operation_id and completed_at is not null;
 if existing is not null then return existing; end if;
 insert into public.commercial_operations(operation_id,operation_type,actor_user_id,request_hash) values(operation_id,'grant_team_cycle_access_batch',auth.uid(),input_hash) on conflict do nothing;
 if not found then raise exception 'Operation is already in progress'; end if;
 select id into definition_id from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1;
 insert into public.team_season_entitlements(team_id,season_id,playing_cycle_id,entitlement_definition_id,state,valid_from,valid_until,source,source_reference,granted_by)
 select c.team_id,(select s.id from public.seasons s where s.playing_cycle_id=c.id order by s.created_at limit 1),c.id,definition_id,grant_state,valid_from,valid_until,case when grant_state='trial' then 'trial' else 'complimentary' end,'admin-batch:'||operation_id,auth.uid()
 from public.team_playing_cycles c where c.id=any(target_cycle_ids) and not exists(select 1 from public.team_season_entitlements e where e.team_id=c.team_id and e.playing_cycle_id=c.id and e.revoked_at is null and now()<=coalesce(e.grace_until,e.valid_until));
 result:=jsonb_build_object('success',true,'cycles',affected,'state',grant_state,'validUntil',valid_until);
 update public.commercial_operations set response=result,completed_at=now() where commercial_operations.operation_id=grant_team_cycle_access_batch.operation_id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'entitlement.batch_granted','playing_cycle_batch',operation_id::text,result,btrim(reason));
 return result;
end $$;
