-- RooBin paid Team foundation: versioned catalogue, billing identities,
-- subscriptions and authoritative team-season entitlements.

create type public.commercial_record_state as enum ('draft', 'published', 'retired');
create type public.commercial_channel as enum ('web', 'ios', 'android', 'invoice', 'admin');
create type public.subscription_state as enum ('trialing', 'active', 'past_due', 'paused', 'cancelled', 'expired');
create type public.entitlement_state as enum ('trial', 'active', 'grace', 'expired', 'revoked');

create table public.commercial_products (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  sport text not null default 'pool',
  created_at timestamptz not null default now()
);

create table public.entitlement_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  version integer not null check (version > 0),
  capabilities jsonb not null default '{}'::jsonb,
  state public.commercial_record_state not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (code, version)
);

create table public.commercial_offerings (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.commercial_products(id),
  code text not null,
  version integer not null check (version > 0),
  customer_type text not null check (customer_type in ('team', 'league', 'club', 'venue')),
  billing_unit text not null check (billing_unit in ('team_season', 'team_year', 'organisation_year', 'venue_year', 'league_team_quantity')),
  billing_interval text not null check (billing_interval in ('one_time', 'season', 'month', 'year')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  tax_behaviour text not null check (tax_behaviour in ('inclusive', 'exclusive', 'provider_calculated')),
  entitlement_definition_id uuid not null references public.entitlement_definitions(id),
  min_quantity integer not null default 1 check (min_quantity > 0),
  max_quantity integer check (max_quantity is null or max_quantity >= min_quantity),
  trial_days integer not null default 0 check (trial_days >= 0),
  renewal_behaviour text not null check (renewal_behaviour in ('manual', 'automatic')),
  sales_channels public.commercial_channel[] not null,
  eligibility jsonb not null default '{}'::jsonb,
  state public.commercial_record_state not null default 'draft',
  published_at timestamptz,
  retired_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (code, version)
);

create table public.commercial_price_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.commercial_offerings(id),
  amount_minor integer not null check (amount_minor >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  tax_behaviour text not null check (tax_behaviour in ('inclusive', 'exclusive', 'provider_calculated')),
  market text not null default 'GB',
  effective_from timestamptz not null,
  effective_to timestamptz,
  state public.commercial_record_state not null default 'draft',
  provider_price_refs jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from)
);

create table public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id),
  customer_type text not null check (customer_type in ('team', 'league', 'club', 'venue')),
  team_id uuid references public.teams(id) on delete restrict,
  provider_customer_refs jsonb not null default '{}'::jsonb,
  billing_name text,
  billing_email text,
  country_code text not null default 'GB',
  tax_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, team_id)
);

create table public.commercial_subscriptions (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id),
  offering_id uuid not null references public.commercial_offerings(id),
  price_version_id uuid not null references public.commercial_price_versions(id),
  team_id uuid not null references public.teams(id) on delete restrict,
  season_id uuid references public.seasons(id) on delete restrict,
  provider text not null check (provider in ('stripe', 'app_store', 'google_play', 'invoice', 'admin')),
  provider_subscription_id text,
  state public.subscription_state not null,
  quantity integer not null default 1 check (quantity > 0),
  current_period_start timestamptz not null,
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (current_period_end > current_period_start),
  unique nulls not distinct (provider, provider_subscription_id)
);

create table public.team_season_entitlements (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete restrict,
  season_id uuid not null references public.seasons(id) on delete restrict,
  subscription_id uuid references public.commercial_subscriptions(id) on delete set null,
  entitlement_definition_id uuid not null references public.entitlement_definitions(id),
  state public.entitlement_state not null,
  valid_from timestamptz not null,
  valid_until timestamptz not null,
  grace_until timestamptz,
  source text not null check (source in ('purchase', 'trial', 'league', 'complimentary', 'correction')),
  source_reference text,
  granted_by uuid references auth.users(id),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until > valid_from),
  check (grace_until is null or grace_until >= valid_until),
  unique nulls not distinct (team_id, season_id, entitlement_definition_id, subscription_id)
);

create table public.commercial_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload jsonb not null,
  status text not null default 'received' check (status in ('received', 'processed', 'failed', 'ignored')),
  attempts integer not null default 0,
  error_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id)
);

create table public.commercial_audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create index team_entitlement_lookup on public.team_season_entitlements (team_id, season_id, state, valid_until);
create index subscription_team_lookup on public.commercial_subscriptions (team_id, state, current_period_end);
create unique index non_overlapping_published_prices on public.commercial_price_versions
  (offering_id, market, effective_from) where state = 'published';

alter table public.commercial_products enable row level security;
alter table public.entitlement_definitions enable row level security;
alter table public.commercial_offerings enable row level security;
alter table public.commercial_price_versions enable row level security;
alter table public.billing_customers enable row level security;
alter table public.commercial_subscriptions enable row level security;
alter table public.team_season_entitlements enable row level security;
alter table public.commercial_events enable row level security;
alter table public.commercial_audit_log enable row level security;

create policy "published products are readable" on public.commercial_products for select to anon, authenticated using (true);
create policy "published entitlement definitions are readable" on public.entitlement_definitions for select to anon, authenticated using (state = 'published' or public.is_platform_admin());
create policy "published offerings are readable" on public.commercial_offerings for select to anon, authenticated using (state = 'published' or public.is_platform_admin());
create policy "published prices are readable" on public.commercial_price_versions for select to anon, authenticated using (state = 'published' or public.is_platform_admin());
create policy "payers read billing identity" on public.billing_customers for select to authenticated using (owner_user_id = auth.uid() or public.is_platform_admin());
create policy "team members read subscriptions" on public.commercial_subscriptions for select to authenticated using (public.is_member_of_team(team_id) or public.is_platform_admin());
create policy "team members read entitlements" on public.team_season_entitlements for select to authenticated using (public.is_member_of_team(team_id) or public.is_platform_admin());

revoke all on public.billing_customers, public.commercial_subscriptions, public.team_season_entitlements, public.commercial_events, public.commercial_audit_log from anon, authenticated;
grant select on public.billing_customers, public.commercial_subscriptions, public.team_season_entitlements to authenticated;
grant select on public.commercial_products, public.entitlement_definitions, public.commercial_offerings, public.commercial_price_versions to anon, authenticated;

create or replace function public.current_team_season_entitlement(target_team_id uuid, target_season_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'id', e.id,
      'state', case
        when e.revoked_at is not null then 'revoked'
        when now() <= e.valid_until then e.state::text
        when e.grace_until is not null and now() <= e.grace_until then 'grace'
        else 'expired'
      end,
      'validFrom', e.valid_from,
      'validUntil', e.valid_until,
      'graceUntil', e.grace_until,
      'source', e.source,
      'capabilities', d.capabilities
    )
    from public.team_season_entitlements e
    join public.entitlement_definitions d on d.id = e.entitlement_definition_id
    where e.team_id = target_team_id and e.season_id = target_season_id
      and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
    order by (e.revoked_at is null) desc, e.valid_until desc
    limit 1
  ), jsonb_build_object('state', 'missing', 'capabilities', '{}'::jsonb));
$$;

create or replace function public.has_team_season_capability(target_team_id uuid, target_season_id uuid, capability text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.team_season_entitlements e
    join public.entitlement_definitions d on d.id = e.entitlement_definition_id
      where e.team_id = target_team_id and e.season_id = target_season_id
        and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
        and e.revoked_at is null and now() >= e.valid_from
        and now() <= coalesce(e.grace_until, e.valid_until)
        and e.state in ('trial', 'active', 'grace')
        and coalesce((d.capabilities ->> capability)::boolean, false)
  );
$$;

revoke all on function public.current_team_season_entitlement(uuid, uuid) from public, anon;
grant execute on function public.current_team_season_entitlement(uuid, uuid) to authenticated;
revoke all on function public.has_team_season_capability(uuid, uuid, text) from public, anon, authenticated;

-- The initial catalogue is data, not a client constant. Provider price/product
-- references are deliberately added after Stripe and App Store setup.
with product as (
  insert into public.commercial_products (code, name, description, sport)
  values ('roobin-fines-team', 'RooBin Fines Team', 'Team fines, subs, match and payment tracking for one playing cycle.', 'pool')
  returning id
), definition as (
  insert into public.entitlement_definitions (code, version, capabilities, state, published_at)
  values ('fines-team-standard', 1, '{"dashboard":true,"matches":true,"fines":true,"subs":true,"payments":true,"team_management":true,"rackem_import":true}'::jsonb, 'published', now())
  returning id
), offering as (
  insert into public.commercial_offerings (
    product_id, code, version, customer_type, billing_unit, billing_interval,
    currency, tax_behaviour, entitlement_definition_id, renewal_behaviour,
    sales_channels, state, published_at
  )
  select product.id, 'team-season-standard', 1, 'team', 'team_season', 'season',
    'GBP', 'provider_calculated', definition.id, 'manual',
    array['web'::public.commercial_channel, 'ios'::public.commercial_channel], 'published', now()
  from product, definition
  returning id
)
insert into public.commercial_price_versions (
  offering_id, amount_minor, currency, tax_behaviour, market,
  effective_from, state
)
select id, 1000, 'GBP', 'provider_calculated', 'GB', now(), 'published' from offering;

comment on table public.commercial_events is 'Immutable ingress/deduplication ledger for Stripe, App Store and future provider events.';
comment on function public.has_team_season_capability is 'Server-side authorization primitive. Clients must not infer write access from displayed pricing.';
