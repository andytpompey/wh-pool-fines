create or replace view public.commercial_offering_performance
with (security_invoker=false) as
select o.id offering_id,o.code,o.version,
 count(distinct s.id) purchases,
 count(distinct s.id) filter(where s.state in ('active','trialing','past_due','paused')) active_subscriptions,
 count(distinct s.id) filter(where s.state='trialing' or exists(select 1 from public.team_season_entitlements e where e.subscription_id=s.id and e.source='trial')) trials,
 count(distinct s.id) filter(where s.state='cancelled') cancellations,
 count(distinct s.id) filter(where (select count(*) from public.commercial_financial_entries f2 where f2.subscription_id=s.id and f2.entry_type='charge')>1) renewed_subscriptions,
 count(distinct r.id) discount_redemptions,
 coalesce(sum(r.undiscounted_amount_minor-r.discounted_amount_minor),0) gross_discount_minor,
 coalesce((select sum(f.gross_amount_minor) from public.commercial_financial_entries f join public.commercial_subscriptions fs on fs.id=f.subscription_id where fs.offering_id=o.id and f.entry_type='charge'),0) gross_revenue_minor,
 coalesce((select -sum(f.gross_amount_minor) from public.commercial_financial_entries f join public.commercial_subscriptions fs on fs.id=f.subscription_id where fs.offering_id=o.id and f.entry_type='refund'),0) refunds_minor,
 case when count(distinct s.id)>0 then round(100.0*count(distinct s.id) filter(where s.state='cancelled')/count(distinct s.id),1) else 0 end cancellation_rate_percent
from public.commercial_offerings o left join public.commercial_subscriptions s on s.offering_id=o.id left join public.commercial_discount_redemptions r on r.subscription_id=s.id
group by o.id,o.code,o.version;
revoke all on public.commercial_offering_performance from anon,authenticated;

create or replace function public.get_commercial_admin_dashboard()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then jsonb_build_object(
  'products',coalesce((select jsonb_agg(to_jsonb(p) order by p.name) from public.commercial_products p),'[]'::jsonb),
  'entitlementDefinitions',coalesce((select jsonb_agg(to_jsonb(d) order by d.code,d.version desc) from public.entitlement_definitions d),'[]'::jsonb),
  'offerings',coalesce((select jsonb_agg(to_jsonb(o) order by o.code,o.version desc) from public.commercial_offerings o),'[]'::jsonb),
  'prices',coalesce((select jsonb_agg(to_jsonb(p) order by p.effective_from desc) from public.commercial_price_versions p),'[]'::jsonb),
  'discounts',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.commercial_discounts d),'[]'::jsonb),
  'metrics',coalesce((select jsonb_agg(to_jsonb(m) order by m.month desc) from public.commercial_monthly_metrics m),'[]'::jsonb),
  'offeringPerformance',coalesce((select jsonb_agg(to_jsonb(p) order by p.code,p.version desc) from public.commercial_offering_performance p),'[]'::jsonb),
  'reconciliationIssues',coalesce((select jsonb_agg(to_jsonb(i) order by i.detected_at desc) from public.commercial_reconciliation_issues i),'[]'::jsonb),
  'enforcementGaps',coalesce((select jsonb_agg(to_jsonb(g) order by g.name) from public.commercial_enforcement_gaps g),'[]'::jsonb),
  'correctionCandidates',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'teamName',t.name,'cycleName',c.name,'state',e.state,'validUntil',e.valid_until) order by e.updated_at desc) from public.team_season_entitlements e join public.teams t on t.id=e.team_id join public.team_playing_cycles c on c.id=e.playing_cycle_id limit 100),'[]'::jsonb),
  'serviceComponents',coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.service_components c),'[]'::jsonb),
  'support',public.commercial_support_summary(),'notifications',public.commercial_notification_summary(),
  'enforcement',(select value from public.commercial_settings where key='entitlement_enforcement')
 ) else null end;
$$;
