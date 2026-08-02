alter table public.commercial_offerings add column lifecycle_policy jsonb not null default '{"retryDays":[1,3,5],"graceDays":7,"graceAccess":"full","permanentFailure":"read_only"}'::jsonb;
alter table public.commercial_offerings add constraint commercial_offering_lifecycle_policy_valid check(
 jsonb_typeof(lifecycle_policy->'retryDays')='array' and (lifecycle_policy->>'graceDays')::integer between 0 and 30
 and lifecycle_policy->>'graceAccess' in ('full','read_only') and lifecycle_policy->>'permanentFailure' in ('read_only','suspend'));

create or replace function public.update_draft_commercial_recovery_policy(target_offering_id uuid,new_policy jsonb,reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.commercial_offerings;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if length(btrim(reason))<8 or jsonb_typeof(new_policy->'retryDays')<>'array' or (new_policy->>'graceDays')::integer not between 0 and 30 or new_policy->>'graceAccess' not in ('full','read_only') or new_policy->>'permanentFailure' not in ('read_only','suspend') then raise exception 'Valid recovery policy and reason are required'; end if;
 select to_jsonb(o) into before_row from public.commercial_offerings o where id=target_offering_id and state='draft' for update;
 if before_row is null then raise exception 'Draft offering not found'; end if;
 update public.commercial_offerings set lifecycle_policy=new_policy where id=target_offering_id returning * into changed;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'offering.recovery_policy_updated','commercial_offering',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 return changed;
end $$;
revoke all on function public.update_draft_commercial_recovery_policy(uuid,jsonb,text) from public,anon;
grant execute on function public.update_draft_commercial_recovery_policy(uuid,jsonb,text) to authenticated;
