begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values ('1c000000-0000-0000-0000-000000000001','policy-member@example.test',now(),now(),now());
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values ('2c000000-0000-0000-0000-000000000001','Policy member','Policy member','policy-member@example.test','1c000000-0000-0000-0000-000000000001','1c000000-0000-0000-0000-000000000001');
insert into public.teams(id,name,join_code,created_by) values ('3c000000-0000-0000-0000-000000000001','Policy Team','POLI0001','2c000000-0000-0000-0000-000000000001');
insert into public.team_memberships(team_id,player_id,role,status) values ('3c000000-0000-0000-0000-000000000001','2c000000-0000-0000-0000-000000000001','captain','active');
insert into public.team_playing_cycles(id,team_id,name,sport,starts_on,ends_on,status) values ('4c000000-0000-0000-0000-000000000001','3c000000-0000-0000-0000-000000000001','Policy Cycle','pool',current_date,current_date+100,'active');
insert into public.seasons(id,team_id,name,type,playing_cycle_id) values ('5c000000-0000-0000-0000-000000000001','3c000000-0000-0000-0000-000000000001','Policy League','League','4c000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1c000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select public.evaluate_commercial_offering_eligibility(id,'3c000000-0000-0000-0000-000000000001','web')->>'reason' from public.commercial_offerings where code='team-season-standard' and state='published' order by version desc limit 1),'ELIGIBLE','published web offer is eligible for a team member');
select is((select public.evaluate_commercial_offering_eligibility(id,'3c000000-0000-0000-0000-000000000001','android')->>'reason' from public.commercial_offerings where code='team-season-standard' and state='published' order by version desc limit 1),'CHANNEL_UNAVAILABLE','unsupported sales channel returns stable reason');
reset role;

insert into public.team_season_entitlements(team_id,season_id,playing_cycle_id,entitlement_definition_id,state,valid_from,valid_until,source)
select '3c000000-0000-0000-0000-000000000001','5c000000-0000-0000-0000-000000000001','4c000000-0000-0000-0000-000000000001',id,'trial',now(),now()+interval '14 days','trial' from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1;
update public.commercial_offerings set eligibility='{"noPreviousTrial":true}' where code='team-season-standard' and state='published';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1c000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select public.evaluate_commercial_offering_eligibility(id,'3c000000-0000-0000-0000-000000000001','web')->>'reason' from public.commercial_offerings where code='team-season-standard' and state='published' order by version desc limit 1),'TRIAL_ALREADY_USED','trial cannot be repeated through a normal team account change');
select throws_ok($$select public.run_commercial_retention('v1.0',true)$$,'42501',null,'authenticated users cannot run retention');
reset role;

insert into public.public_request_limits(request_hash,request_kind,window_started_at,request_count) values ('old-policy-fingerprint','support',now()-interval '2 days',1);
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select is((public.run_commercial_retention('v1.0',true)->>'requestLimits')::integer,1,'retention preview reports eligible rate-limit records');
reset role;
select is((select count(*)::integer from public.public_request_limits where request_hash='old-policy-fingerprint'),1,'preview does not mutate retained data');
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select is((public.run_commercial_retention('v1.0',false)->>'requestLimits')::integer,1,'scheduled retention execution reports its action');
reset role;
select is((select count(*)::integer from public.public_request_limits where request_hash='old-policy-fingerprint'),0,'retention execution removes expired fingerprint');

select * from finish();
rollback;
