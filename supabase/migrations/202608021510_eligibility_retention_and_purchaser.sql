alter table public.commercial_retention_runs alter column actor_user_id drop not null;
alter table public.commercial_retention_runs add column actor_type text not null default 'administrator' check(actor_type in ('administrator','scheduled_service'));

create or replace function public.evaluate_commercial_offering_eligibility(target_offering_id uuid,target_team_id uuid,target_channel public.commercial_channel)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare offering public.commercial_offerings; cycle_sport text; previous_trial boolean; previous_purchase boolean; country text; rule jsonb;
begin
 if not (public.is_member_of_team(target_team_id) or public.is_platform_admin()) then return jsonb_build_object('eligible',false,'reason','TEAM_ACCESS_REQUIRED'); end if;
 select * into offering from public.commercial_offerings where id=target_offering_id and state='published' and now()>=coalesce(published_at,created_at);
 if offering.id is null then return jsonb_build_object('eligible',false,'reason','OFFERING_UNAVAILABLE'); end if;
 if not target_channel=any(offering.sales_channels) then return jsonb_build_object('eligible',false,'reason','CHANNEL_UNAVAILABLE'); end if;
 rule:=offering.eligibility;
 select sport into cycle_sport from public.team_playing_cycles where team_id=target_team_id order by starts_on desc nulls last limit 1;
 if rule?'sports' and not coalesce(rule->'sports','[]'::jsonb)?coalesce(cycle_sport,'pool') then return jsonb_build_object('eligible',false,'reason','SPORT_UNAVAILABLE'); end if;
 select exists(select 1 from public.team_season_entitlements where team_id=target_team_id and source='trial') into previous_trial;
 select exists(select 1 from public.commercial_subscriptions where team_id=target_team_id and state in ('active','past_due','cancelled','expired')) into previous_purchase;
 if coalesce((rule->>'firstPurchaseOnly')::boolean,false) and previous_purchase then return jsonb_build_object('eligible',false,'reason','FIRST_PURCHASE_REQUIRED'); end if;
 if coalesce((rule->>'noPreviousTrial')::boolean,false) and previous_trial then return jsonb_build_object('eligible',false,'reason','TRIAL_ALREADY_USED'); end if;
 select country_code into country from public.billing_customers where team_id=target_team_id order by updated_at desc limit 1;
 if rule?'countries' and country is not null and not (rule->'countries')?country then return jsonb_build_object('eligible',false,'reason','MARKET_UNAVAILABLE'); end if;
 if rule?'effectiveFrom' and now()<(rule->>'effectiveFrom')::timestamptz then return jsonb_build_object('eligible',false,'reason','OFFER_NOT_STARTED'); end if;
 if rule?'effectiveUntil' and now()>=(rule->>'effectiveUntil')::timestamptz then return jsonb_build_object('eligible',false,'reason','OFFER_ENDED'); end if;
 return jsonb_build_object('eligible',true,'reason','ELIGIBLE','trialDays',offering.trial_days,'paymentMethodRequired',coalesce((rule->>'paymentMethodRequired')::boolean,false),'conversionBehaviour',coalesce(rule->>'conversionBehaviour','manual'));
end $$;
revoke all on function public.evaluate_commercial_offering_eligibility(uuid,uuid,public.commercial_channel) from public,anon;
grant execute on function public.evaluate_commercial_offering_eligibility(uuid,uuid,public.commercial_channel) to authenticated;

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
revoke all on function public.run_commercial_retention(text,boolean) from public,anon,authenticated;
grant execute on function public.run_commercial_retention(text,boolean) to service_role;

create or replace function public.current_team_cycle_entitlement(target_team_id uuid,target_playing_cycle_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object(
  'id',e.id,'state',case when e.revoked_at is not null then 'revoked' when now()<=e.valid_until then e.state::text when e.grace_until is not null and now()<=e.grace_until then 'grace' else 'expired' end,
  'validFrom',e.valid_from,'validUntil',e.valid_until,'graceUntil',e.grace_until,'source',e.source,'capabilities',d.capabilities,
  'purchaser',case when public.can_manage_team_operations(target_team_id) then coalesce(b.billing_name,b.billing_email,case when e.source in ('trial','complimentary','correction') then 'RooBin administrator' end) end
 ) from public.team_season_entitlements e join public.entitlement_definitions d on d.id=e.entitlement_definition_id left join public.commercial_subscriptions s on s.id=e.subscription_id left join public.billing_customers b on b.id=s.billing_customer_id
 where e.team_id=target_team_id and e.playing_cycle_id=target_playing_cycle_id and (public.is_member_of_team(target_team_id) or public.is_platform_admin()) order by (e.revoked_at is null) desc,e.valid_until desc limit 1),jsonb_build_object('state','missing','capabilities','{}'::jsonb));
$$;

create or replace view public.team_cycle_access_summary
with (security_invoker=true) as
select c.id,c.team_id,c.name,c.sport,c.starts_on,c.ends_on,c.status,
 case when e.revoked_at is not null then 'revoked' when e.id is null then 'missing' when now()<=e.valid_until then e.state::text when e.grace_until is not null and now()<=e.grace_until then 'grace' else 'expired' end entitlement_state,
 e.valid_until entitlement_valid_until,e.source entitlement_source,
 case when public.can_manage_team_operations(c.team_id) then coalesce(b.billing_name,b.billing_email,case when e.source in ('trial','complimentary','correction') then 'RooBin administrator' end) end entitlement_purchaser
from public.team_playing_cycles c left join lateral (select candidate.* from public.team_season_entitlements candidate where candidate.team_id=c.team_id and candidate.playing_cycle_id=c.id order by (candidate.revoked_at is null) desc,candidate.valid_until desc limit 1) e on true
left join public.commercial_subscriptions s on s.id=e.subscription_id left join public.billing_customers b on b.id=s.billing_customer_id;
