create or replace function public.get_commercial_admin_dashboard()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then jsonb_build_object(
  'products',coalesce((select jsonb_agg(to_jsonb(p) order by p.name) from public.commercial_products p),'[]'::jsonb),
  'entitlementDefinitions',coalesce((select jsonb_agg(to_jsonb(d) order by d.code,d.version desc) from public.entitlement_definitions d),'[]'::jsonb),
  'offerings',coalesce((select jsonb_agg(to_jsonb(o) order by o.code,o.version desc) from public.commercial_offerings o),'[]'::jsonb),
  'prices',coalesce((select jsonb_agg(to_jsonb(p) order by p.effective_from desc) from public.commercial_price_versions p),'[]'::jsonb),
  'discounts',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.commercial_discounts d),'[]'::jsonb),
  'metrics',coalesce((select jsonb_agg(to_jsonb(m) order by m.month desc) from public.commercial_monthly_metrics m),'[]'::jsonb),
  'reconciliationIssues',coalesce((select jsonb_agg(to_jsonb(i) order by i.detected_at desc) from public.commercial_reconciliation_issues i),'[]'::jsonb),
  'enforcementGaps',coalesce((select jsonb_agg(to_jsonb(g) order by g.name) from public.commercial_enforcement_gaps g),'[]'::jsonb),
  'correctionCandidates',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'teamName',t.name,'cycleName',c.name,'state',e.state,'validUntil',e.valid_until) order by e.updated_at desc) from public.team_season_entitlements e join public.teams t on t.id=e.team_id join public.team_playing_cycles c on c.id=e.playing_cycle_id limit 100),'[]'::jsonb),
  'serviceComponents',coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.service_components c),'[]'::jsonb),
  'support',public.commercial_support_summary(),'notifications',public.commercial_notification_summary(),
  'enforcement',(select value from public.commercial_settings where key='entitlement_enforcement')
 ) else null end;
$$;
