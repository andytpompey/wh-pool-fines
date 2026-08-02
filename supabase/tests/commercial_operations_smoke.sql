begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at) values
  ('18000000-0000-0000-0000-000000000001', 'commercial-admin@example.test', now(), now(), now()),
  ('18000000-0000-0000-0000-000000000002', 'commercial-captain2@example.test', now(), now(), now());
insert into public.app_users (id, is_platform_admin) values ('18000000-0000-0000-0000-000000000001', true);
insert into public.players (id, name, display_name, email, user_id, auth_user_id) values
  ('28000000-0000-0000-0000-000000000001', 'Admin', 'Admin', 'commercial-admin@example.test', '18000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000001'),
  ('28000000-0000-0000-0000-000000000002', 'Captain', 'Captain', 'commercial-captain2@example.test', '18000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000002');
insert into public.teams (id, name, join_code, created_by) values
  ('38000000-0000-0000-0000-000000000001', 'Grant Test Team', 'GRANT001', '28000000-0000-0000-0000-000000000002');
insert into public.team_memberships (team_id, player_id, role, status) values
  ('38000000-0000-0000-0000-000000000001', '28000000-0000-0000-0000-000000000002', 'captain', 'active');
insert into public.seasons (id, team_id, name, type) values
  ('48000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', 'Pilot', 'League');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok(
  $$select public.grant_team_season_access('78000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001','trial','trial',now(),now()+interval '14 days','Founding pilot approval')$$,
  'P0001', 'Commercial administrator access required', 'captain cannot self-grant a trial'
);

select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $$select public.grant_team_season_access('78000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001','trial','trial','2026-08-01','2026-08-15','Founding pilot approval')$$,
  'platform admin grants a bounded trial'
);
select lives_ok(
  $$select public.grant_team_season_access('78000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001','trial','trial','2026-08-01','2026-08-15','Founding pilot approval')$$,
  'identical operation retry returns its stored response'
);
reset role;
select is((select count(*)::integer from public.team_season_entitlements where team_id='38000000-0000-0000-0000-000000000001'), 1, 'retry creates exactly one entitlement');
select is((select count(*)::integer from public.commercial_operations where operation_id='78000000-0000-0000-0000-000000000001'), 1, 'operation is recorded once');
select is((select count(*)::integer from public.commercial_audit_log where action='entitlement.granted'), 1, 'grant is audited once');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$select public.grant_team_season_access('78000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001','complimentary','complimentary','2026-08-01','2026-08-15','Different approved grant')$$,
  'P0001', 'Operation key was reused with different input', 'idempotency key cannot be reused with changed input'
);
select lives_ok(
  $sql$select public.revoke_team_season_access((select id from public.team_season_entitlements where team_id='38000000-0000-0000-0000-000000000001'),'Pilot withdrawn by owner')$sql$,
  'platform admin can revoke with a reason'
);

select * from finish();
rollback;
