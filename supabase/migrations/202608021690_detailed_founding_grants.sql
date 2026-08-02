alter table public.team_season_entitlements add column grant_terms jsonb;

create or replace view public.commercial_enforcement_gaps with(security_invoker=false) as
select c.id playing_cycle_id,c.team_id,c.name,c.status,c.starts_on,c.ends_on,t.name team_name,c.sport
from public.team_playing_cycles c join public.teams t on t.id=c.team_id
where c.status in ('active','planned') and not exists(select 1 from public.team_season_entitlements e where e.playing_cycle_id=c.id and e.team_id=c.team_id and e.revoked_at is null and e.state in ('trial','active','grace','complimentary') and now()<=coalesce(e.grace_until,e.valid_until));
revoke all on public.commercial_enforcement_gaps from anon,authenticated;

create or replace function public.grant_founding_access_batch(operation_id uuid,target_cycle_ids uuid[],grant_state public.entitlement_state,valid_from timestamptz,valid_until timestamptz,agreed_price_minor integer,discount_minor integer,grant_owner uuid,reason text,preview_only boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare input_hash text; existing jsonb; existing_hash text; definition_id uuid; affected jsonb; exclusions jsonb; result jsonb; owner_id uuid;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 owner_id:=coalesce(grant_owner,auth.uid());
 if grant_state not in ('trial','complimentary') or valid_until<=valid_from or cardinality(target_cycle_ids)<1 or cardinality(target_cycle_ids)>500 or agreed_price_minor<0 or discount_minor<0 or discount_minor>agreed_price_minor or length(btrim(reason))<12 or not exists(select 1 from auth.users where id=owner_id) then raise exception 'Valid grant selection, terms, owner and detailed reason are required'; end if;
 if (select count(*) from public.team_playing_cycles where id=any(target_cycle_ids))<>cardinality(target_cycle_ids) then raise exception 'One or more playing cycles were not found'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('playingCycleId',c.id,'teamId',c.team_id,'teamName',t.name,'cycleName',c.name) order by t.name,c.name),'[]'::jsonb) into affected from public.team_playing_cycles c join public.teams t on t.id=c.team_id where c.id=any(target_cycle_ids) and not exists(select 1 from public.team_season_entitlements e where e.team_id=c.team_id and e.playing_cycle_id=c.id and e.revoked_at is null and now()<=coalesce(e.grace_until,e.valid_until));
 select coalesce(jsonb_agg(jsonb_build_object('playingCycleId',c.id,'teamId',c.team_id,'teamName',t.name,'cycleName',c.name,'reason','ALREADY_COVERED') order by t.name,c.name),'[]'::jsonb) into exclusions from public.team_playing_cycles c join public.teams t on t.id=c.team_id where c.id=any(target_cycle_ids) and exists(select 1 from public.team_season_entitlements e where e.team_id=c.team_id and e.playing_cycle_id=c.id and e.revoked_at is null and now()<=coalesce(e.grace_until,e.valid_until));
 result:=jsonb_build_object('preview',preview_only,'affected',affected,'exclusions',exclusions,'terms',jsonb_build_object('state',grant_state,'validFrom',valid_from,'validUntil',valid_until,'agreedPriceMinor',agreed_price_minor,'discountMinor',discount_minor,'ownerUserId',owner_id,'reason',btrim(reason)));
 if preview_only then return result; end if;
 input_hash:=encode(extensions.digest(concat_ws('|',array_to_string(target_cycle_ids,','),grant_state,valid_from,valid_until,agreed_price_minor,discount_minor,owner_id,reason),'sha256'),'hex');
 select response,request_hash into existing,existing_hash from public.commercial_operations where commercial_operations.operation_id=grant_founding_access_batch.operation_id and completed_at is not null;
 if existing is not null then if existing_hash<>input_hash then raise exception 'Operation key was reused with different input'; end if; return existing; end if;
 insert into public.commercial_operations(operation_id,operation_type,actor_user_id,request_hash) values(operation_id,'grant_founding_access_batch',auth.uid(),input_hash) on conflict do nothing;
 if not found then raise exception 'Operation is already in progress'; end if;
 select id into definition_id from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1;
 insert into public.team_season_entitlements(team_id,season_id,playing_cycle_id,entitlement_definition_id,state,valid_from,valid_until,source,source_reference,granted_by,grant_terms)
 select c.team_id,(select s.id from public.seasons s where s.playing_cycle_id=c.id order by s.created_at limit 1),c.id,definition_id,grant_state,valid_from,valid_until,case when grant_state='trial' then 'trial' else 'complimentary' end,'founding-grant:'||operation_id,auth.uid(),jsonb_build_object('agreedPriceMinor',agreed_price_minor,'discountMinor',discount_minor,'ownerUserId',owner_id,'reason',btrim(reason))
 from public.team_playing_cycles c where c.id=any(target_cycle_ids) and not exists(select 1 from public.team_season_entitlements e where e.team_id=c.team_id and e.playing_cycle_id=c.id and e.revoked_at is null and now()<=coalesce(e.grace_until,e.valid_until));
 result:=result||jsonb_build_object('preview',false,'success',true);
 update public.commercial_operations set response=result,completed_at=now() where commercial_operations.operation_id=grant_founding_access_batch.operation_id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'founding_access.batch_granted','playing_cycle_batch',operation_id::text,result,btrim(reason));
 return result;
end $$;
revoke all on function public.grant_founding_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,integer,integer,uuid,text,boolean) from public,anon;
grant execute on function public.grant_founding_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,integer,integer,uuid,text,boolean) to authenticated;
