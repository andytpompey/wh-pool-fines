create or replace function public.run_commercial_retention(target_policy_version text,preview_only boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare old_limits integer; old_events integer; old_support integer; old_billing integer; result jsonb;
begin
 if auth.role()<>'service_role' and not public.is_platform_admin() then raise exception 'Retention operator access required'; end if;
 if length(btrim(target_policy_version))<3 then raise exception 'Policy version is required'; end if;
 select count(*) into old_limits from public.public_request_limits where window_started_at<now()-interval '24 hours';
 select count(*) into old_events from public.commercial_events where received_at<now()-interval '90 days' and payload<>jsonb_build_object('minimised',true);
 select count(*) into old_support from public.support_cases where status in ('resolved','closed') and resolved_at<now()-interval '24 months' and (contact_email<>concat('retained-',id,'@invalid.local') or contact_name is not null);
 select count(*) into old_billing from public.billing_customers b where updated_at<now()-interval '7 years' and (billing_email is not null or billing_name is not null or tax_identifier is not null) and not exists(select 1 from public.commercial_subscriptions s where s.billing_customer_id=b.id and s.state in ('trialing','active','past_due','paused'));
 result:=jsonb_build_object('preview',preview_only,'requestLimits',old_limits,'eventPayloads',old_events,'supportContacts',old_support,'billingContacts',old_billing);
 if not preview_only then
  delete from public.public_request_limits where window_started_at<now()-interval '24 hours';
  update public.commercial_events set payload=jsonb_build_object('minimised',true,'providerEventId',provider_event_id,'eventType',event_type) where received_at<now()-interval '90 days' and payload<>jsonb_build_object('minimised',true);
  update public.support_cases set contact_name=null,contact_email=concat('retained-',id,'@invalid.local'),description='Retained case metadata; personal content removed by policy.',consent_to_contact=false,updated_at=now() where status in ('resolved','closed') and resolved_at<now()-interval '24 months';
  update public.billing_customers b set billing_name=null,billing_email=null,tax_identifier=null,updated_at=now() where updated_at<now()-interval '7 years' and not exists(select 1 from public.commercial_subscriptions s where s.billing_customer_id=b.id and s.state in ('trialing','active','past_due','paused'));
 end if;
 insert into public.commercial_retention_runs(policy_version,cutoff_at,state,anonymised_billing_contacts,deleted_request_limits,deleted_event_payloads,result,actor_user_id,actor_type)
 values(btrim(target_policy_version),now(),case when preview_only then 'preview' else 'completed' end,case when preview_only then 0 else old_billing end,case when preview_only then 0 else old_limits end,case when preview_only then 0 else old_events end,result,auth.uid(),case when auth.role()='service_role' then 'scheduled_service' else 'administrator' end);
 return result;
end $$;
