begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id,email,email_confirmed_at,created_at,updated_at) values
 ('19000000-0000-0000-0000-000000000001','enforcement-admin@example.test',now(),now(),now()),
 ('19000000-0000-0000-0000-000000000002','enforcement-captain@example.test',now(),now(),now());
insert into public.app_users (id,is_platform_admin) values ('19000000-0000-0000-0000-000000000001',true);
insert into public.players (id,name,display_name,email,user_id,auth_user_id) values
 ('29000000-0000-0000-0000-000000000001','Admin','Admin','enforcement-admin@example.test','19000000-0000-0000-0000-000000000001','19000000-0000-0000-0000-000000000001'),
 ('29000000-0000-0000-0000-000000000002','Captain','Captain','enforcement-captain@example.test','19000000-0000-0000-0000-000000000002','19000000-0000-0000-0000-000000000002');
insert into public.teams (id,name,join_code,created_by) values
 ('39000000-0000-0000-0000-000000000001','Enforcement Team','ENFORCE1','29000000-0000-0000-0000-000000000002');
insert into public.team_memberships (team_id,player_id,role,status) values
 ('39000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-000000000002','captain','active');
insert into public.seasons (id,team_id,name,type) values
 ('49000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000001','Covered Cycle','League');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"19000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok(
 $$select public.set_commercial_enforcement('enforce','Production readiness gate test')$$,
 'P0001','Cannot enforce while 1 active or planned playing cycles lack entitlement','enforcement gate identifies unentitled active cycle'
);
select lives_ok(
 $$select public.grant_team_season_access('79000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000001','trial','trial',now()-interval '1 day',now()+interval '14 days','Enforcement coverage test')$$,
 'admin grants migration coverage'
);
select lives_ok($$select public.set_commercial_enforcement('enforce','All production cycles are covered')$$,'admin enables enforcement after gaps close');
reset role;
select is(public.commercial_enforcement_mode(),'enforce','authoritative mode is enforce');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"19000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok(
 $$insert into public.matches (id,team_id,season_id,date,opponent,submitted,venue) values ('59000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000001','2026-08-02','Covered Opponent',false,'home')$$,
 'covered cycle permits operational write'
);
select lives_ok(
 $$insert into public.seasons (id,team_id,name,type) values ('49000000-0000-0000-0000-000000000002','39000000-0000-0000-0000-000000000001','Renewal Setup','League')$$,
 'captain can create the next cycle in order to renew'
);
select throws_ok(
 $$insert into public.matches (id,team_id,season_id,date,opponent,submitted,venue) values ('59000000-0000-0000-0000-000000000002','39000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000002','2026-08-03','Uncovered Opponent',false,'home')$$,
 'P0001','Commercial entitlement required [COMMERCIAL_ENTITLEMENT_REQUIRED]','uncovered cycle blocks operational write server-side'
);
select ok(not public.commercial_team_write_allowed('39000000-0000-0000-0000-000000000001','unknown_capability'),'unknown capability cannot be inferred from a client price');

select * from finish();
rollback;
