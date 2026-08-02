create or replace view public.commercial_reconciliation_issues
with (security_invoker = false) as
select 'subscription_without_entitlement'::text issue_type, s.id::text entity_id, s.provider, s.updated_at detected_at
from public.commercial_subscriptions s
where s.state in ('trialing','active','past_due') and not exists (select 1 from public.team_season_entitlements e where e.subscription_id=s.id)
union all
select 'entitlement_without_subscription',e.id::text,e.source,e.updated_at
from public.team_season_entitlements e
where e.source='purchase' and e.subscription_id is null
union all
select 'failed_provider_event',ce.id::text,ce.provider,ce.received_at
from public.commercial_events ce where ce.status='failed'
union all
select 'payment_without_financial_entry',s.id::text,s.provider,s.updated_at
from public.commercial_subscriptions s
where s.state='active' and not exists(select 1 from public.commercial_financial_entries f where f.subscription_id=s.id and f.entry_type='charge');

create or replace view public.commercial_monthly_metrics
with (security_invoker = false) as
select date_trunc('month',month_source)::date as month,
  count(distinct subscription_id) filter(where entry_type='charge') as paid_team_seasons,
  coalesce(sum(gross_amount_minor) filter(where entry_type='charge'),0) as gross_amount_minor,
  coalesce(-sum(gross_amount_minor) filter(where entry_type='refund'),0) as refund_amount_minor,
  coalesce(sum(processor_fee_minor),0) as processor_fee_minor,
  coalesce(sum(tax_amount_minor),0) as tax_amount_minor,
  coalesce(sum(net_amount_minor),0) as net_amount_minor
from (select f.*,f.occurred_at month_source from public.commercial_financial_entries f) source
group by date_trunc('month',month_source);

create or replace view public.commercial_renewal_notifications_due
with (security_invoker = false) as
select e.id entitlement_id,e.team_id,e.playing_cycle_id,e.valid_until,b.billing_email,
  c.name cycle_name,t.name team_name,
  (e.valid_until::date-current_date) days_remaining
from public.team_season_entitlements e
join public.team_playing_cycles c on c.id=e.playing_cycle_id
join public.teams t on t.id=e.team_id
left join public.commercial_subscriptions s on s.id=e.subscription_id
left join public.billing_customers b on b.id=s.billing_customer_id
where e.revoked_at is null and e.state in ('trial','active','grace','complimentary')
  and (e.valid_until::date-current_date) in (30,14,3)
  and b.billing_email is not null;

revoke all on public.commercial_reconciliation_issues,public.commercial_monthly_metrics,public.commercial_renewal_notifications_due from anon,authenticated;

create or replace function public.get_commercial_admin_dashboard()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when public.is_platform_admin() then jsonb_build_object(
    'offerings',coalesce((select jsonb_agg(to_jsonb(o) order by o.code,o.version desc) from public.commercial_offerings o),'[]'::jsonb),
    'prices',coalesce((select jsonb_agg(to_jsonb(p) order by p.effective_from desc) from public.commercial_price_versions p),'[]'::jsonb),
    'discounts',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.commercial_discounts d),'[]'::jsonb),
    'metrics',coalesce((select jsonb_agg(to_jsonb(m) order by m.month desc) from public.commercial_monthly_metrics m),'[]'::jsonb),
    'reconciliationIssues',coalesce((select jsonb_agg(to_jsonb(i) order by i.detected_at desc) from public.commercial_reconciliation_issues i),'[]'::jsonb),
    'enforcementGaps',coalesce((select jsonb_agg(to_jsonb(g) order by g.name) from public.commercial_enforcement_gaps g),'[]'::jsonb),
    'support',public.commercial_support_summary(),
    'enforcement',(select value from public.commercial_settings where key='entitlement_enforcement')
  ) else null end;
$$;

create or replace function public.schedule_commercial_price(
  target_offering_id uuid,new_amount_minor integer,new_currency text,new_tax_behaviour text,
  new_market text,new_effective_from timestamptz,new_effective_to timestamptz,
  existing_subscription_treatment text,approval_reason text
)
returns public.commercial_price_versions language plpgsql security definer set search_path = '' as $$
declare created public.commercial_price_versions;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if new_amount_minor<0 or new_currency!~'^[A-Z]{3}$' or new_tax_behaviour not in ('inclusive','exclusive','provider_calculated') then raise exception 'Price data is invalid'; end if;
  if new_effective_from<=now() and exists(select 1 from public.commercial_price_versions where offering_id=target_offering_id and state='published') then raise exception 'Replacement prices must be scheduled in the future'; end if;
  if existing_subscription_treatment not in ('retain','migrate_at_renewal','require_acceptance') then raise exception 'Subscription treatment is required'; end if;
  if length(btrim(approval_reason))<8 then raise exception 'Approval reason is required'; end if;
  if exists(select 1 from public.commercial_price_versions p where p.offering_id=target_offering_id and p.market=upper(new_market) and p.state='published' and tstzrange(p.effective_from,coalesce(p.effective_to,'infinity'))&&tstzrange(new_effective_from,coalesce(new_effective_to,'infinity'))) then raise exception 'Published price periods cannot overlap'; end if;
  insert into public.commercial_price_versions(offering_id,amount_minor,currency,tax_behaviour,market,effective_from,effective_to,state,created_by,provider_price_refs)
  values(target_offering_id,new_amount_minor,upper(new_currency),new_tax_behaviour,upper(new_market),new_effective_from,new_effective_to,'published',auth.uid(),jsonb_build_object('existingSubscriptionTreatment',existing_subscription_treatment)) returning * into created;
  insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason)
  values(auth.uid(),'price.scheduled','commercial_price_version',created.id::text,to_jsonb(created),btrim(approval_reason));
  return created;
end $$;

create or replace function public.create_commercial_discount(
  discount_name text,discount_type text,discount_value numeric,discount_currency text,
  valid_from timestamptz,valid_until timestamptz,total_limit integer,per_customer_limit integer,
  eligibility jsonb,provider_refs jsonb,approval_reason text
)
returns public.commercial_discounts language plpgsql security definer set search_path = '' as $$
declare created public.commercial_discounts;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if length(btrim(discount_name))<3 or discount_type not in ('fixed','percentage') or discount_value<=0 then raise exception 'Discount data is invalid'; end if;
  if discount_type='percentage' and discount_value>100 then raise exception 'Percentage cannot exceed 100'; end if;
  if valid_until is not null and valid_until<=valid_from then raise exception 'Discount validity is invalid'; end if;
  if length(btrim(approval_reason))<8 then raise exception 'Approval reason is required'; end if;
  insert into public.commercial_discounts(name,discount_type,amount_minor,percentage,currency,valid_from,valid_until,total_redemption_limit,per_customer_limit,eligibility,state,provider_refs,created_by)
  values(btrim(discount_name),discount_type,case when discount_type='fixed' then discount_value::integer end,case when discount_type='percentage' then discount_value end,case when discount_type='fixed' then upper(discount_currency) end,valid_from,valid_until,total_limit,coalesce(per_customer_limit,1),coalesce(eligibility,'{}'), 'published',coalesce(provider_refs,'{}'),auth.uid()) returning * into created;
  insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason)
  values(auth.uid(),'discount.published','commercial_discount',created.id::text,to_jsonb(created),btrim(approval_reason));
  return created;
end $$;

revoke all on function public.get_commercial_admin_dashboard() from public,anon;
revoke all on function public.schedule_commercial_price(uuid,integer,text,text,text,timestamptz,timestamptz,text,text) from public,anon;
revoke all on function public.create_commercial_discount(text,text,numeric,text,timestamptz,timestamptz,integer,integer,jsonb,jsonb,text) from public,anon;
grant execute on function public.get_commercial_admin_dashboard() to authenticated;
grant execute on function public.schedule_commercial_price(uuid,integer,text,text,text,timestamptz,timestamptz,text,text) to authenticated;
grant execute on function public.create_commercial_discount(text,text,numeric,text,timestamptz,timestamptz,integer,integer,jsonb,jsonb,text) to authenticated;
grant execute on function public.publish_commercial_offering(uuid,text) to authenticated;
grant execute on function public.retire_commercial_offering(uuid,text) to authenticated;
