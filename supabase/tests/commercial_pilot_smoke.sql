begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values ('1f000000-0000-0000-0000-000000000001','pilot-admin@example.test',now(),now(),now()),('1f000000-0000-0000-0000-000000000002','pilot-captain@example.test',now(),now(),now());
insert into public.app_users(id,is_platform_admin) values ('1f000000-0000-0000-0000-000000000001',true),('1f000000-0000-0000-0000-000000000002',false);
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values ('2f000000-0000-0000-0000-000000000001','Pilot captain','Pilot captain','pilot-captain@example.test','1f000000-0000-0000-0000-000000000002','1f000000-0000-0000-0000-000000000002');
insert into public.teams(id,name,join_code,created_by) values ('3f000000-0000-0000-0000-000000000001','Pilot Team','PILT0001','2f000000-0000-0000-0000-000000000001');
insert into public.team_memberships(team_id,player_id,role,status) values ('3f000000-0000-0000-0000-000000000001','2f000000-0000-0000-0000-000000000001','captain','active');
insert into public.team_playing_cycles(id,team_id,name,sport,starts_on,ends_on,status) values ('4f000000-0000-0000-0000-000000000001','3f000000-0000-0000-0000-000000000001','Pilot Cycle','pool',current_date,current_date+60,'planned');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.create_commercial_pilot('{"name":"Blocked Pilot","leagueName":"League","startsOn":"2026-08-03","endsOn":"2026-09-30","playingCycleIds":["4f000000-0000-0000-0000-000000000001"],"committeeFeedbackAt":"2026-08-20T18:00:00Z","captainFeedbackAt":"2026-08-21T18:00:00Z"}'::jsonb,'Unauthorised pilot creation')$$,'P0001','Commercial administrator access required','ordinary users cannot create pilot evaluations');
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_commercial_pilot('{"name":"Founding Pilot","leagueName":"Test League","startsOn":"2026-08-03","endsOn":"2026-09-30","playingCycleIds":["4f000000-0000-0000-0000-000000000001"],"committeeFeedbackAt":"2026-08-20T18:00:00Z","captainFeedbackAt":"2026-08-21T18:00:00Z","successCriteria":{"activatedTeams":1,"willingnessToRenew":true}}'::jsonb,'Approved founding pilot baseline')$$,'admin creates pilot with pre-activation baseline');
reset role;
select set_config('test.pilot_id',(select id::text from public.commercial_pilots where name='Founding Pilot'),true);
select is((select baseline->>'selectedTeams' from public.commercial_pilots where name='Founding Pilot'),'1','baseline records selected teams before activation');
select is((select count(*)::integer from public.commercial_pilot_feedback_points f join public.commercial_pilots p on p.id=f.pilot_id where p.name='Founding Pilot'),2,'committee and representative captain feedback points are scheduled');
select set_config('test.feedback_id',(select f.id::text from public.commercial_pilot_feedback_points f where f.pilot_id=current_setting('test.pilot_id')::uuid and f.audience='league_committee'),true);
select has_view('public','commercial_pilot_adoption','privacy-safe adoption view exists');
select ok(not has_table_privilege('authenticated','public.commercial_pilots','select'),'pilot evaluation records are restricted from normal clients');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($sql$select public.update_commercial_pilot_evaluation(current_setting('test.pilot_id')::uuid,'active',current_setting('test.feedback_id')::uuid,'{"captainTimeSavedMinutes":15,"willingnessToRenew":4,"responses":3}'::jsonb,null,array[]::text[],'Aggregate committee feedback recorded')$sql$,'aggregate feedback completes a scheduled point without participant text');
select throws_ok($sql$select public.update_commercial_pilot_evaluation(current_setting('test.pilot_id')::uuid,'completed',null,'{}','renewed',array[]::text[],'Attempt without decision reasons')$sql$,'P0001','Renewal outcome and reasons are required to complete a pilot','pilot cannot complete without renewal reasons');
select lives_ok($sql$select public.update_commercial_pilot_evaluation(current_setting('test.pilot_id')::uuid,'completed',null,'{}','renewed',array['captain time saved','committee approved renewal'],'Approved pilot renewal decision')$sql$,'pilot completion records renewal outcome and reasons');
reset role;

select * from finish();
rollback;
