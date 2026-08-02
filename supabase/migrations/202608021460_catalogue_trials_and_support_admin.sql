create table public.support_case_updates (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.support_cases(id) on delete cascade,
 update_type text not null check(update_type in ('internal_note','customer_update','state_change','resolution')),
 message text not null,
 customer_visible boolean not null default false,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.support_case_updates enable row level security;
revoke all on public.support_case_updates from anon,authenticated;

create or replace function public.clone_commercial_offering(source_offering_id uuid,new_code text,reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare source public.commercial_offerings; created public.commercial_offerings; next_version integer;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if new_code!~'^[a-z0-9][a-z0-9-]{2,63}$' or length(btrim(reason))<8 then raise exception 'Valid code and reason are required'; end if;
 select * into source from public.commercial_offerings where id=source_offering_id;
 if source.id is null then raise exception 'Source offering not found'; end if;
 select coalesce(max(version),0)+1 into next_version from public.commercial_offerings where code=new_code;
 insert into public.commercial_offerings(product_id,code,version,customer_type,billing_unit,billing_interval,currency,tax_behaviour,entitlement_definition_id,min_quantity,max_quantity,trial_days,renewal_behaviour,sales_channels,eligibility,state,created_by)
 values(source.product_id,new_code,next_version,source.customer_type,source.billing_unit,source.billing_interval,source.currency,source.tax_behaviour,source.entitlement_definition_id,source.min_quantity,source.max_quantity,source.trial_days,source.renewal_behaviour,source.sales_channels,source.eligibility,'draft',auth.uid()) returning * into created;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'offering.cloned','commercial_offering',created.id::text,to_jsonb(created),btrim(reason));
 return created;
end $$;

create or replace function public.update_draft_commercial_offering(target_offering_id uuid,changes jsonb,reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.commercial_offerings;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if length(btrim(reason))<8 then raise exception 'Change reason is required'; end if;
 select * into changed from public.commercial_offerings where id=target_offering_id for update;
 before_row:=to_jsonb(changed);
 if changed.id is null or changed.state<>'draft' then raise exception 'Draft offering not found'; end if;
 update public.commercial_offerings set
  trial_days=coalesce((changes->>'trialDays')::integer,trial_days),
  renewal_behaviour=coalesce(changes->>'renewalBehaviour',renewal_behaviour),
  eligibility=coalesce(changes->'eligibility',eligibility),
  sales_channels=coalesce((select array_agg(value::public.commercial_channel) from jsonb_array_elements_text(changes->'salesChannels')),sales_channels),
  min_quantity=coalesce((changes->>'minQuantity')::integer,min_quantity),
  max_quantity=case when changes?'maxQuantity' then nullif(changes->>'maxQuantity','')::integer else max_quantity end
 where id=target_offering_id returning * into changed;
 if changed.renewal_behaviour='automatic' and changed.billing_interval in ('one_time','season') then raise exception 'Automatic renewal requires a fixed month or year interval'; end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'offering.draft_updated','commercial_offering',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 return changed;
end $$;

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

create or replace function public.get_support_admin_queue()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then coalesce((select jsonb_agg(to_jsonb(c) order by case c.priority when 'urgent' then 1 when 'high' then 2 else 3 end,c.created_at) from public.support_cases c where c.status not in ('resolved','closed')),'[]'::jsonb) else null end;
$$;

create or replace function public.update_support_case(target_case_id uuid,new_status text,new_priority text,customer_message text,internal_note text,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.support_cases;
begin
 if not public.is_platform_admin() then raise exception 'Support administrator access required'; end if;
 if new_status not in ('open','acknowledged','waiting_customer','resolved','closed') or new_priority not in ('low','normal','high','urgent') or length(btrim(reason))<8 then raise exception 'Valid case state, priority and reason are required'; end if;
 select to_jsonb(c) into before_row from public.support_cases c where id=target_case_id for update;
 update public.support_cases set status=new_status,priority=new_priority,assigned_to=coalesce(assigned_to,auth.uid()),resolved_at=case when new_status in ('resolved','closed') then now() else null end,updated_at=now() where id=target_case_id returning * into changed;
 if changed.id is null then raise exception 'Support case not found'; end if;
 if nullif(btrim(customer_message),'') is not null then insert into public.support_case_updates(case_id,update_type,message,customer_visible,created_by) values(changed.id,case when new_status in ('resolved','closed') then 'resolution' else 'customer_update' end,btrim(customer_message),true,auth.uid()); end if;
 if nullif(btrim(internal_note),'') is not null then insert into public.support_case_updates(case_id,update_type,message,customer_visible,created_by) values(changed.id,'internal_note',btrim(internal_note),false,auth.uid()); end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'support_case.updated','support_case',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 return to_jsonb(changed);
end $$;

revoke all on function public.clone_commercial_offering(uuid,text,text) from public,anon;
revoke all on function public.update_draft_commercial_offering(uuid,jsonb,text) from public,anon;
revoke all on function public.grant_team_cycle_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,text,boolean) from public,anon;
revoke all on function public.get_support_admin_queue() from public,anon;
revoke all on function public.update_support_case(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.clone_commercial_offering(uuid,text,text) to authenticated;
grant execute on function public.update_draft_commercial_offering(uuid,jsonb,text) to authenticated;
grant execute on function public.grant_team_cycle_access_batch(uuid,uuid[],public.entitlement_state,timestamptz,timestamptz,text,boolean) to authenticated;
grant execute on function public.get_support_admin_queue() to authenticated;
grant execute on function public.update_support_case(uuid,text,text,text,text,text) to authenticated;
