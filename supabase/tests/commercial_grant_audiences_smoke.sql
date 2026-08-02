begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values
 ('1f000000-0000-0000-0000-000000000001','audience-admin@example.test',now(),now(),now()),
 ('1f000000-0000-0000-0000-000000000002','audience-user@example.test',now(),now(),now());
insert into public.app_users(id,is_platform_admin) values
 ('1f000000-0000-0000-0000-000000000001',true),('1f000000-0000-0000-0000-000000000002',false);
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values
 ('2f000000-0000-0000-0000-000000000001','Audience user','Audience user','audience-user@example.test','1f000000-0000-0000-0000-000000000002','1f000000-0000-0000-0000-000000000002');
insert into public.teams(id,name,join_code,created_by) values
 ('3f000000-0000-0000-0000-000000000001','Alpha Team','AUDI0001','2f000000-0000-0000-0000-000000000001'),
 ('3f000000-0000-0000-0000-000000000002','Beta Team','AUDI0002','2f000000-0000-0000-0000-000000000001');
insert into public.team_playing_cycles(id,team_id,name,sport,starts_on,ends_on,status) values
 ('4f100000-0000-0000-0000-000000000001','3f000000-0000-0000-0000-000000000001','2026 League','pool',current_date,current_date+90,'planned'),
 ('4f100000-0000-0000-0000-000000000002','3f000000-0000-0000-0000-000000000002','2026 League','pool',current_date,current_date+90,'planned');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is(public.get_commercial_grant_audiences(),null,'normal users cannot list commercial grant audiences');
select throws_ok($$select public.save_commercial_grant_audience(null,'Test League','league',null,array['4f100000-0000-0000-0000-000000000001'::uuid],'Unauthorised audience creation')$$,'P0001','Commercial administrator access required','normal users cannot create audiences');

select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select set_config('test.league_id',(public.save_commercial_grant_audience(null,'Test League','league',null,array['4f100000-0000-0000-0000-000000000001'::uuid,'4f100000-0000-0000-0000-000000000002'::uuid],'Approved founding league roster')->>'id'),true);
select ok(current_setting('test.league_id')::uuid is not null,'admin creates a complete league audience');
select lives_ok($sql$select public.save_commercial_grant_audience(null,'Division One','division',current_setting('test.league_id')::uuid,array['4f100000-0000-0000-0000-000000000001'::uuid],'Approved founding division roster')$sql$,'admin creates a selected division audience');
select is(jsonb_array_length(public.get_commercial_grant_audiences()),2,'admin lists league and division audiences');
reset role;
select is((select count(*)::integer from public.commercial_grant_audience_cycles where audience_id=current_setting('test.league_id')::uuid),2,'league audience contains all selected team cycles');
select is((select count(*)::integer from public.commercial_audit_log where action='grant_audience.created'),2,'audience creation is audited');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.save_commercial_grant_audience(null,'Bad Division','division',null,array['4f100000-0000-0000-0000-000000000001'::uuid],'Invalid division parent test')$$,'P0001','Division audiences require an active league audience','division requires a league parent');

select is(jsonb_array_length(public.grant_founding_audience_access('5f000000-0000-0000-0000-000000000001',current_setting('test.league_id')::uuid,null,'trial',now(),now()+interval '30 days',1000,1000,null,'Whole league founding access',true)->'affected'),2,'whole-league preview resolves every audience cycle');
select set_config('test.preview_cycles',(public.grant_founding_audience_access('5f000000-0000-0000-0000-000000000001',current_setting('test.league_id')::uuid,null,'trial',now(),now()+interval '30 days',1000,1000,null,'Whole league founding access',true)->'audienceCycleIds')::text,true);
select is((public.grant_founding_audience_access('5f000000-0000-0000-0000-000000000001',current_setting('test.league_id')::uuid,array(select jsonb_array_elements_text(current_setting('test.preview_cycles')::jsonb)::uuid),'trial',now(),now()+interval '30 days',1000,1000,null,'Whole league founding access',false)->>'success')::boolean,true,'confirmed audience grant executes');
reset role;
select is((select count(*)::integer from public.team_season_entitlements where source_reference='founding-grant:5f000000-0000-0000-0000-000000000001'),2,'whole-league grant creates one entitlement per team cycle');
select is((select after_data->>'audienceName' from public.commercial_audit_log where action='founding_access.batch_granted' and entity_id='5f000000-0000-0000-0000-000000000001'),'Test League','grant audit records the named audience');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1f000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($sql$select public.save_commercial_grant_audience(current_setting('test.league_id')::uuid,'Test League','league',null,array['4f100000-0000-0000-0000-000000000001'::uuid],'League roster changed after preview')$sql$,'admin can update audience membership with an audit reason');
select throws_ok($sql$select public.grant_founding_audience_access('5f000000-0000-0000-0000-000000000002',current_setting('test.league_id')::uuid,array['4f100000-0000-0000-0000-000000000001'::uuid,'4f100000-0000-0000-0000-000000000002'::uuid],'complimentary',now(),now()+interval '30 days',1000,1000,null,'Changed roster confirmation guard',false)$sql$,'P0001','Grant audience changed since preview; preview again','confirmation rejects an audience changed after preview');
reset role;
select is((select count(*)::integer from public.commercial_audit_log where action='grant_audience.updated'),1,'audience membership update is audited');

select * from finish();
rollback;
