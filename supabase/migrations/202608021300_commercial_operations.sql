-- Commercial administration, discounts, financial ledger, controlled grants,
-- and rollout-safe enforcement configuration.

create table public.commercial_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.commercial_settings (key, value) values
  ('entitlement_enforcement', '{"mode":"observe","expiredPolicy":"read_only","graceDays":7}'::jsonb),
  ('renewal_reminders', '{"daysBefore":[30,14,3]}'::jsonb);

create table public.commercial_discounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  discount_type text not null check (discount_type in ('fixed', 'percentage')),
  amount_minor integer check (amount_minor is null or amount_minor > 0),
  percentage numeric(5,2) check (percentage is null or percentage > 0 and percentage <= 100),
  currency text check (currency is null or currency ~ '^[A-Z]{3}$'),
  valid_from timestamptz not null,
  valid_until timestamptz,
  total_redemption_limit integer check (total_redemption_limit is null or total_redemption_limit > 0),
  per_customer_limit integer not null default 1 check (per_customer_limit > 0),
  eligibility jsonb not null default '{}'::jsonb,
  compatible_discount_ids uuid[] not null default '{}'::uuid[],
  state public.commercial_record_state not null default 'draft',
  provider_refs jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check ((discount_type = 'fixed' and amount_minor is not null and percentage is null and currency is not null)
      or (discount_type = 'percentage' and percentage is not null and amount_minor is null)),
  check (valid_until is null or valid_until > valid_from)
);

create table public.commercial_discount_codes (
  id uuid primary key default gen_random_uuid(),
  discount_id uuid not null references public.commercial_discounts(id),
  code_digest text not null unique,
  code_hint text not null,
  customer_id uuid references public.billing_customers(id),
  max_redemptions integer not null default 1 check (max_redemptions > 0),
  redemption_count integer not null default 0 check (redemption_count >= 0),
  revoked_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (redemption_count <= max_redemptions)
);

create table public.commercial_discount_redemptions (
  id uuid primary key default gen_random_uuid(),
  discount_code_id uuid not null references public.commercial_discount_codes(id),
  billing_customer_id uuid not null references public.billing_customers(id),
  subscription_id uuid references public.commercial_subscriptions(id),
  undiscounted_amount_minor integer not null,
  discounted_amount_minor integer not null,
  currency text not null,
  provider_reference text,
  redeemed_at timestamptz not null default now(),
  check (discounted_amount_minor >= 0 and discounted_amount_minor <= undiscounted_amount_minor)
);

create table public.commercial_financial_entries (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.commercial_subscriptions(id),
  provider text not null,
  provider_reference text not null,
  entry_type text not null check (entry_type in ('charge', 'refund', 'dispute', 'dispute_reversal', 'tax_adjustment', 'fee_adjustment', 'credit')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  gross_amount_minor integer not null,
  discount_amount_minor integer not null default 0,
  tax_amount_minor integer not null default 0,
  processor_fee_minor integer not null default 0,
  net_amount_minor integer not null,
  receipt_url text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (provider, provider_reference, entry_type)
);

create table public.commercial_operations (
  operation_id uuid primary key,
  operation_type text not null,
  actor_user_id uuid not null references auth.users(id),
  request_hash text not null,
  response jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.commercial_settings enable row level security;
alter table public.commercial_discounts enable row level security;
alter table public.commercial_discount_codes enable row level security;
alter table public.commercial_discount_redemptions enable row level security;
alter table public.commercial_financial_entries enable row level security;
alter table public.commercial_operations enable row level security;
revoke all on public.commercial_settings, public.commercial_discounts, public.commercial_discount_codes,
  public.commercial_discount_redemptions, public.commercial_financial_entries, public.commercial_operations
  from anon, authenticated;

create or replace function public.publish_commercial_offering(target_offering_id uuid, approval_reason text)
returns public.commercial_offerings
language plpgsql security definer set search_path = '' as $$
declare target public.commercial_offerings;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if approval_reason is null or length(btrim(approval_reason)) < 8 then raise exception 'Approval reason is required'; end if;
  select * into target from public.commercial_offerings where id = target_offering_id for update;
  if target.id is null then raise exception 'Offering not found'; end if;
  if target.state <> 'draft' then raise exception 'Only draft offerings can be published'; end if;
  if not exists (select 1 from public.entitlement_definitions where id = target.entitlement_definition_id and state = 'published') then
    raise exception 'Entitlement definition must be published first';
  end if;
  update public.commercial_offerings set state = 'published', published_at = now() where id = target.id returning * into target;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, after_data, reason)
  values (auth.uid(), 'offering.published', 'commercial_offering', target.id::text, to_jsonb(target), btrim(approval_reason));
  return target;
end $$;

create or replace function public.retire_commercial_offering(target_offering_id uuid, retirement_reason text)
returns public.commercial_offerings
language plpgsql security definer set search_path = '' as $$
declare target public.commercial_offerings; before_row jsonb;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if retirement_reason is null or length(btrim(retirement_reason)) < 8 then raise exception 'Retirement reason is required'; end if;
  select * into target from public.commercial_offerings o where o.id = target_offering_id for update;
  before_row := to_jsonb(target);
  if target.id is null or target.state <> 'published' then raise exception 'Published offering not found'; end if;
  update public.commercial_offerings set state = 'retired', retired_at = now() where id = target.id returning * into target;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (auth.uid(), 'offering.retired', 'commercial_offering', target.id::text, before_row, to_jsonb(target), btrim(retirement_reason));
  return target;
end $$;

create or replace function public.grant_team_season_access(
  operation_id uuid,
  target_team_id uuid,
  target_season_id uuid,
  grant_state public.entitlement_state,
  grant_source text,
  valid_from timestamptz,
  valid_until timestamptz,
  reason text
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare definition_id uuid; existing jsonb; result jsonb; input_hash text;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if grant_state not in ('trial', 'complimentary') or grant_source not in ('trial', 'complimentary', 'correction') then raise exception 'Unsupported administrative grant'; end if;
  if valid_until <= valid_from or reason is null or length(btrim(reason)) < 8 then raise exception 'Valid period and reason are required'; end if;
  if not exists (select 1 from public.seasons where id = target_season_id and team_id = target_team_id) then raise exception 'Team season not found'; end if;
  input_hash := encode(extensions.digest(concat_ws('|', target_team_id, target_season_id, grant_state, grant_source, valid_from, valid_until, reason), 'sha256'), 'hex');
  select response into existing from public.commercial_operations where commercial_operations.operation_id = grant_team_season_access.operation_id and completed_at is not null;
  if existing is not null then
    if (select op.request_hash from public.commercial_operations op where op.operation_id = grant_team_season_access.operation_id) <> input_hash then raise exception 'Operation key was reused with different input'; end if;
    return existing;
  end if;
  insert into public.commercial_operations (operation_id, operation_type, actor_user_id, request_hash)
  values (operation_id, 'grant_team_season_access', auth.uid(), input_hash) on conflict do nothing;
  if not found then raise exception 'Operation is already in progress'; end if;
  select id into definition_id from public.entitlement_definitions where code = 'fines-team-standard' and state = 'published' order by version desc limit 1;
  insert into public.team_season_entitlements (team_id, season_id, entitlement_definition_id, state, valid_from, valid_until, source, source_reference, granted_by)
  values (target_team_id, target_season_id, definition_id, grant_state, valid_from, valid_until, grant_source, 'admin:' || operation_id, auth.uid());
  result := jsonb_build_object('success', true, 'teamId', target_team_id, 'seasonId', target_season_id, 'state', grant_state, 'validUntil', valid_until);
  update public.commercial_operations set response = result, completed_at = now() where commercial_operations.operation_id = grant_team_season_access.operation_id;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, after_data, reason)
  values (auth.uid(), 'entitlement.granted', 'team_season', concat(target_team_id, ':', target_season_id), result, btrim(reason));
  return result;
end $$;

create or replace function public.revoke_team_season_access(target_entitlement_id uuid, reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare changed public.team_season_entitlements; before_row jsonb;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if reason is null or length(btrim(reason)) < 8 then raise exception 'Revocation reason is required'; end if;
  select to_jsonb(e.*) into before_row from public.team_season_entitlements e where id = target_entitlement_id for update;
  update public.team_season_entitlements set state = 'revoked', revoked_at = now(), updated_at = now()
    where id = target_entitlement_id and revoked_at is null returning * into changed;
  if changed.id is null then raise exception 'Active entitlement not found'; end if;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (auth.uid(), 'entitlement.revoked', 'team_season_entitlement', changed.id::text, before_row, to_jsonb(changed), btrim(reason));
  return jsonb_build_object('success', true, 'entitlementId', changed.id);
end $$;

revoke all on function public.publish_commercial_offering(uuid, text) from public, anon, authenticated;
revoke all on function public.retire_commercial_offering(uuid, text) from public, anon, authenticated;
revoke all on function public.grant_team_season_access(uuid, uuid, uuid, public.entitlement_state, text, timestamptz, timestamptz, text) from public, anon;
revoke all on function public.revoke_team_season_access(uuid, text) from public, anon;
grant execute on function public.grant_team_season_access(uuid, uuid, uuid, public.entitlement_state, text, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.revoke_team_season_access(uuid, text) to authenticated;

comment on table public.commercial_settings is 'Commercial rollout remains observe-only until production entitlements and expiry communications are verified.';
