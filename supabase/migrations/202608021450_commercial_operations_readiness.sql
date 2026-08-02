create table public.commercial_platform_usage_months (
  month date primary key check (month=date_trunc('month',month)::date),
  supabase_database_bytes bigint not null default 0 check (supabase_database_bytes>=0),
  supabase_storage_bytes bigint not null default 0 check (supabase_storage_bytes>=0),
  supabase_egress_bytes bigint not null default 0 check (supabase_egress_bytes>=0),
  supabase_mau integer not null default 0 check (supabase_mau>=0),
  authentication_emails integer not null default 0 check (authentication_emails>=0),
  vercel_bandwidth_bytes bigint not null default 0 check (vercel_bandwidth_bytes>=0),
  vercel_function_invocations bigint not null default 0 check (vercel_function_invocations>=0),
  variable_cost_minor integer not null default 0 check (variable_cost_minor>=0),
  fixed_cost_minor integer not null default 0 check (fixed_cost_minor>=0),
  currency text not null default 'GBP' check(currency~'^[A-Z]{3}$'),
  evidence jsonb not null default '{}'::jsonb,
  recorded_by uuid not null references auth.users(id),
  recorded_at timestamptz not null default now()
);

create table public.commercial_operator_cases (
  id uuid primary key default gen_random_uuid(),
  case_type text not null check(case_type in ('reconciliation','dispute','refund','access_correction','abuse_review','billing_transfer','retention','incident_action')),
  state text not null default 'open' check(state in ('open','investigating','waiting_approval','resolved','closed')),
  priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
  subscription_id uuid references public.commercial_subscriptions(id),
  entitlement_id uuid references public.team_season_entitlements(id),
  provider_reference text,
  summary text not null,
  safe_details jsonb not null default '{}'::jsonb,
  assigned_to uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.commercial_retention_runs (
  id uuid primary key default gen_random_uuid(),
  policy_version text not null,
  cutoff_at timestamptz not null,
  state text not null check(state in ('preview','completed','failed')),
  anonymised_billing_contacts integer not null default 0,
  deleted_request_limits integer not null default 0,
  deleted_event_payloads integer not null default 0,
  result jsonb not null default '{}'::jsonb,
  actor_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.commercial_platform_usage_months enable row level security;
alter table public.commercial_operator_cases enable row level security;
alter table public.commercial_retention_runs enable row level security;
revoke all on public.commercial_platform_usage_months,public.commercial_operator_cases,public.commercial_retention_runs from anon,authenticated;

create or replace view public.commercial_unit_economics
with (security_invoker=false) as
select m.month,
  m.paid_team_seasons,
  count(distinct e.team_id) filter(where e.source='trial') as trial_teams,
  count(distinct e.team_id) filter(where e.source='complimentary') as complimentary_teams,
  count(distinct e.team_id) as entitled_teams,
  m.gross_amount_minor,m.refund_amount_minor,m.processor_fee_minor,m.tax_amount_minor,m.net_amount_minor,
  coalesce(u.variable_cost_minor,0)+coalesce(u.fixed_cost_minor,0) platform_cost_minor,
  case when m.paid_team_seasons>0 then round((coalesce(u.variable_cost_minor,0)+coalesce(u.fixed_cost_minor,0))::numeric/m.paid_team_seasons,2) end cost_per_paid_team_season_minor,
  u.supabase_database_bytes,u.supabase_storage_bytes,u.supabase_egress_bytes,u.supabase_mau,u.authentication_emails,u.vercel_bandwidth_bytes,u.vercel_function_invocations
from public.commercial_monthly_metrics m
left join public.commercial_platform_usage_months u on u.month=m.month
left join public.team_season_entitlements e on date_trunc('month',e.created_at)::date=m.month
group by m.month,m.paid_team_seasons,m.gross_amount_minor,m.refund_amount_minor,m.processor_fee_minor,m.tax_amount_minor,m.net_amount_minor,
 u.variable_cost_minor,u.fixed_cost_minor,u.supabase_database_bytes,u.supabase_storage_bytes,u.supabase_egress_bytes,u.supabase_mau,u.authentication_emails,u.vercel_bandwidth_bytes,u.vercel_function_invocations;
revoke all on public.commercial_unit_economics from anon,authenticated;

create or replace function public.record_commercial_platform_usage(target_month date,usage jsonb,reason text)
returns public.commercial_platform_usage_months language plpgsql security definer set search_path='' as $$
declare result public.commercial_platform_usage_months;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if target_month<>date_trunc('month',target_month)::date or length(btrim(reason))<8 then raise exception 'Month and evidence reason are required'; end if;
 insert into public.commercial_platform_usage_months(month,supabase_database_bytes,supabase_storage_bytes,supabase_egress_bytes,supabase_mau,authentication_emails,vercel_bandwidth_bytes,vercel_function_invocations,variable_cost_minor,fixed_cost_minor,currency,evidence,recorded_by)
 values(target_month,coalesce((usage->>'supabaseDatabaseBytes')::bigint,0),coalesce((usage->>'supabaseStorageBytes')::bigint,0),coalesce((usage->>'supabaseEgressBytes')::bigint,0),coalesce((usage->>'supabaseMau')::integer,0),coalesce((usage->>'authenticationEmails')::integer,0),coalesce((usage->>'vercelBandwidthBytes')::bigint,0),coalesce((usage->>'vercelFunctionInvocations')::bigint,0),coalesce((usage->>'variableCostMinor')::integer,0),coalesce((usage->>'fixedCostMinor')::integer,0),coalesce(upper(usage->>'currency'),'GBP'),coalesce(usage->'evidence','{}'),auth.uid())
 on conflict(month) do update set supabase_database_bytes=excluded.supabase_database_bytes,supabase_storage_bytes=excluded.supabase_storage_bytes,supabase_egress_bytes=excluded.supabase_egress_bytes,supabase_mau=excluded.supabase_mau,authentication_emails=excluded.authentication_emails,vercel_bandwidth_bytes=excluded.vercel_bandwidth_bytes,vercel_function_invocations=excluded.vercel_function_invocations,variable_cost_minor=excluded.variable_cost_minor,fixed_cost_minor=excluded.fixed_cost_minor,currency=excluded.currency,evidence=excluded.evidence,recorded_by=auth.uid(),recorded_at=now() returning * into result;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'usage.recorded','commercial_platform_usage_month',target_month::text,to_jsonb(result),btrim(reason));
 return result;
end $$;

create or replace function public.correct_team_cycle_access(target_entitlement_id uuid,new_state public.entitlement_state,new_valid_until timestamptz,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.team_season_entitlements;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if new_state not in ('trial','active','grace','expired','revoked','cancelled','refunded','complimentary') or length(btrim(reason))<12 then raise exception 'Correction state and detailed reason are required'; end if;
 select to_jsonb(e) into before_row from public.team_season_entitlements e where id=target_entitlement_id for update;
 if before_row is null then raise exception 'Entitlement not found'; end if;
 update public.team_season_entitlements set state=new_state,valid_until=coalesce(new_valid_until,valid_until),revoked_at=case when new_state='revoked' then now() else revoked_at end,updated_at=now() where id=target_entitlement_id returning * into changed;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'entitlement.corrected','team_season_entitlement',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 insert into public.commercial_operator_cases(case_type,state,priority,entitlement_id,summary,safe_details,resolved_at) values('access_correction','resolved','normal',changed.id,'Entitlement correction completed',jsonb_build_object('state',new_state,'validUntil',changed.valid_until),now());
 return jsonb_build_object('success',true,'entitlementId',changed.id,'state',changed.state,'validUntil',changed.valid_until);
end $$;

revoke all on function public.record_commercial_platform_usage(date,jsonb,text) from public,anon;
revoke all on function public.correct_team_cycle_access(uuid,public.entitlement_state,timestamptz,text) from public,anon;
grant execute on function public.record_commercial_platform_usage(date,jsonb,text) to authenticated;
grant execute on function public.correct_team_cycle_access(uuid,public.entitlement_state,timestamptz,text) to authenticated;
