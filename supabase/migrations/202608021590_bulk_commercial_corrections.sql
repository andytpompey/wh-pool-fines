create or replace function public.correct_team_cycle_access_batch(operation_id uuid,target_entitlement_ids uuid[],new_state public.entitlement_state,new_valid_until timestamptz,reason text,preview_only boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb; input_hash text; existing jsonb; existing_hash text; result jsonb;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if cardinality(target_entitlement_ids)<1 or cardinality(target_entitlement_ids)>100 or new_state not in ('trial','active','grace','expired','revoked','cancelled','refunded','complimentary') or length(btrim(reason))<12 then raise exception 'Correction selection, state and detailed reason are required'; end if;
 if (select count(*) from public.team_season_entitlements where id=any(target_entitlement_ids))<>cardinality(target_entitlement_ids) then raise exception 'One or more entitlements were not found'; end if;
 select jsonb_agg(jsonb_build_object('entitlementId',e.id,'teamId',e.team_id,'playingCycleId',e.playing_cycle_id,'beforeState',e.state,'afterState',new_state,'beforeValidUntil',e.valid_until,'afterValidUntil',coalesce(new_valid_until,e.valid_until)) order by e.id) into rows from public.team_season_entitlements e where e.id=any(target_entitlement_ids);
 if preview_only then return jsonb_build_object('preview',true,'count',cardinality(target_entitlement_ids),'changes',rows); end if;
 input_hash:=encode(extensions.digest(concat_ws('|',array_to_string(target_entitlement_ids,','),new_state,new_valid_until,reason),'sha256'),'hex');
 select response,request_hash into existing,existing_hash from public.commercial_operations where commercial_operations.operation_id=correct_team_cycle_access_batch.operation_id and completed_at is not null;
 if existing is not null then if existing_hash<>input_hash then raise exception 'Operation key was reused with different input'; end if; return existing; end if;
 insert into public.commercial_operations(operation_id,operation_type,actor_user_id,request_hash) values(operation_id,'correct_team_cycle_access_batch',auth.uid(),input_hash) on conflict do nothing;
 if not found then raise exception 'Operation is already in progress'; end if;
 update public.team_season_entitlements set state=new_state,valid_until=coalesce(new_valid_until,valid_until),revoked_at=case when new_state='revoked' then now() else revoked_at end,updated_at=now() where id=any(target_entitlement_ids);
 result:=jsonb_build_object('success',true,'count',cardinality(target_entitlement_ids),'changes',rows);
 update public.commercial_operations set response=result,completed_at=now() where commercial_operations.operation_id=correct_team_cycle_access_batch.operation_id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'entitlement.batch_corrected','entitlement_batch',operation_id::text,result,btrim(reason));
 insert into public.commercial_operator_cases(case_type,state,priority,summary,safe_details,resolved_at) values('access_correction','resolved','high','Bulk entitlement correction completed',jsonb_build_object('operationId',operation_id,'count',cardinality(target_entitlement_ids),'state',new_state),now());
 return result;
end $$;
revoke all on function public.correct_team_cycle_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,text,boolean) from public,anon;
grant execute on function public.correct_team_cycle_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,text,boolean) to authenticated;
