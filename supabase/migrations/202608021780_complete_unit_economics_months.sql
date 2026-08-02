create or replace view public.commercial_unit_economics
with (security_invoker=false) as
with months as (
  select month from public.commercial_monthly_metrics
  union
  select month from public.commercial_platform_usage_months
), entitlement_months as (
  select date_trunc('month',e.created_at)::date as entitlement_month,
    count(distinct e.team_id) filter(where e.source='trial') trial_teams,
    count(distinct e.team_id) filter(where e.source='complimentary') complimentary_teams,
    count(distinct e.team_id) entitled_teams
  from public.team_season_entitlements e group by date_trunc('month',e.created_at)::date
)
select months.month,
  coalesce(m.paid_team_seasons,0)::bigint paid_team_seasons,
  coalesce(e.trial_teams,0)::bigint trial_teams,
  coalesce(e.complimentary_teams,0)::bigint complimentary_teams,
  coalesce(e.entitled_teams,0)::bigint entitled_teams,
  coalesce(m.gross_amount_minor,0)::bigint gross_amount_minor,
  coalesce(m.refund_amount_minor,0)::bigint refund_amount_minor,
  coalesce(m.processor_fee_minor,0)::bigint processor_fee_minor,
  coalesce(m.tax_amount_minor,0)::bigint tax_amount_minor,
  coalesce(m.net_amount_minor,0)::bigint net_amount_minor,
  (coalesce(u.variable_cost_minor,0)+coalesce(u.fixed_cost_minor,0))::integer platform_cost_minor,
  case when coalesce(m.paid_team_seasons,0)>0 then round((coalesce(u.variable_cost_minor,0)+coalesce(u.fixed_cost_minor,0))::numeric/m.paid_team_seasons,2) end cost_per_paid_team_season_minor,
  coalesce(u.supabase_database_bytes,0)::bigint supabase_database_bytes,
  coalesce(u.supabase_storage_bytes,0)::bigint supabase_storage_bytes,
  coalesce(u.supabase_egress_bytes,0)::bigint supabase_egress_bytes,
  coalesce(u.supabase_mau,0)::integer supabase_mau,
  coalesce(u.authentication_emails,0)::integer authentication_emails,
  coalesce(u.vercel_bandwidth_bytes,0)::bigint vercel_bandwidth_bytes,
  coalesce(u.vercel_function_invocations,0)::bigint vercel_function_invocations
from months left join public.commercial_monthly_metrics m using(month)
left join public.commercial_platform_usage_months u using(month)
left join entitlement_months e on e.entitlement_month=months.month;
revoke all on public.commercial_unit_economics from anon,authenticated;
