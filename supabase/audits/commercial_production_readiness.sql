-- Read-only inventory for the backend calls made when Commercial Admin loads.
-- A deployment is not ready unless missing_functions is an empty array.
with required_functions(name) as (
  values
    ('get_commercial_admin_dashboard'),
    ('get_support_admin_queue'),
    ('get_pending_billing_recoveries'),
    ('get_commercial_pilot_dashboard'),
    ('get_commercial_grant_audiences'),
    ('get_incident_admin_queue'),
    ('get_commercial_usage_dashboard')
), available_functions as (
  select distinct p.proname as name
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
)
select coalesce(jsonb_agg(required_functions.name order by required_functions.name), '[]'::jsonb) as missing_functions
from required_functions
left join available_functions using (name)
where available_functions.name is null;

-- A deployment is not ready unless missing_tables is an empty array.
with required_tables(name) as (
  values
    ('commercial_products'),
    ('commercial_offerings'),
    ('commercial_price_versions'),
    ('commercial_subscriptions'),
    ('commercial_audit_log'),
    ('billing_customers'),
    ('support_cases'),
    ('service_incidents'),
    ('service_components'),
    ('team_playing_cycles'),
    ('team_season_entitlements')
), available_tables as (
  select table_name as name
  from information_schema.tables
  where table_schema = 'public'
)
select coalesce(jsonb_agg(required_tables.name order by required_tables.name), '[]'::jsonb) as missing_tables
from required_tables
left join available_tables using (name)
where available_tables.name is null;
