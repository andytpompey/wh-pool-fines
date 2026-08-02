begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select is(
  (select amount_minor from public.commercial_price_versions where state = 'published' order by effective_from desc limit 1),
  1000,
  'published Team season price is GBP 10 in minor units'
);
select is(
  (select currency from public.commercial_price_versions where state = 'published' order by effective_from desc limit 1),
  'GBP',
  'published Team season price uses GBP'
);
select is(
  (select billing_unit from public.commercial_offerings where code = 'team-season-standard' and state = 'published'),
  'team_season',
  'offer is scoped to a team season'
);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at) values
  ('17000000-0000-0000-0000-000000000001', 'commercial-captain@example.test', now(), now(), now()),
  ('17000000-0000-0000-0000-000000000002', 'commercial-member@example.test', now(), now(), now()),
  ('17000000-0000-0000-0000-000000000003', 'commercial-outsider@example.test', now(), now(), now());
insert into public.players (id, name, display_name, email, user_id, auth_user_id) values
  ('27000000-0000-0000-0000-000000000001', 'Captain', 'Captain', 'commercial-captain@example.test', '17000000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000001'),
  ('27000000-0000-0000-0000-000000000002', 'Member', 'Member', 'commercial-member@example.test', '17000000-0000-0000-0000-000000000002', '17000000-0000-0000-0000-000000000002'),
  ('27000000-0000-0000-0000-000000000003', 'Outsider', 'Outsider', 'commercial-outsider@example.test', '17000000-0000-0000-0000-000000000003', '17000000-0000-0000-0000-000000000003');
insert into public.teams (id, name, join_code, created_by) values
  ('37000000-0000-0000-0000-000000000001', 'Commercial Test Team', 'COMTEST1', '27000000-0000-0000-0000-000000000001');
insert into public.team_memberships (team_id, player_id, role, status) values
  ('37000000-0000-0000-0000-000000000001', '27000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('37000000-0000-0000-0000-000000000001', '27000000-0000-0000-0000-000000000002', 'member', 'active');
insert into public.seasons (id, team_id, name, type) values
  ('47000000-0000-0000-0000-000000000001', '37000000-0000-0000-0000-000000000001', '2026/27', 'League');
insert into public.team_season_entitlements (
  team_id, season_id, entitlement_definition_id, state, valid_from, valid_until, source
)
select '37000000-0000-0000-0000-000000000001', '47000000-0000-0000-0000-000000000001', id,
  'trial', now() - interval '1 day', now() + interval '13 days', 'trial'
from public.entitlement_definitions where code = 'fines-team-standard' and version = 1;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((public.current_team_season_entitlement('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001')->>'state'), 'trial', 'captain sees trial state');
reset role;
select ok(public.has_team_season_capability('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001','matches'), 'server capability check succeeds during trial');
set local role authenticated;
select ok(not has_table_privilege('authenticated', 'public.team_season_entitlements', 'insert'), 'client cannot self-grant entitlement');
select ok(not has_table_privilege('authenticated', 'public.commercial_events', 'select'), 'payment event payloads are not client-readable');

select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((public.current_team_season_entitlement('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001')->>'state'), 'trial', 'team member shares team entitlement');

select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select is((public.current_team_season_entitlement('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001')->>'state'), 'missing', 'outsider cannot discover entitlement');
reset role;
select ok(not public.has_team_season_capability('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001','matches'), 'outsider capability check does not grant access');

update public.team_season_entitlements set valid_from = now() - interval '3 days', valid_until = now() - interval '2 days', grace_until = now() - interval '1 day';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((public.current_team_season_entitlement('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001')->>'state'), 'expired', 'expired status is calculated from authoritative timestamps');
reset role;
select ok(not public.has_team_season_capability('37000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000001','matches'), 'expired entitlement does not authorize capability');

select * from finish();
rollback;
