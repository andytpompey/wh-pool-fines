begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values
 ('1d000000-0000-0000-0000-000000000001','workflow-admin@example.test',now(),now(),now()),
 ('1d000000-0000-0000-0000-000000000002','workflow-owner@example.test',now(),now(),now()),
 ('1d000000-0000-0000-0000-000000000003','workflow-replacement@example.test',now(),now(),now()),
 ('1d000000-0000-0000-0000-000000000004','workflow-approver@example.test',now(),now(),now());
insert into public.app_users(id,is_platform_admin) values
 ('1d000000-0000-0000-0000-000000000001',true),('1d000000-0000-0000-0000-000000000002',false),('1d000000-0000-0000-0000-000000000003',false),('1d000000-0000-0000-0000-000000000004',true);
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values ('2d000000-0000-0000-0000-000000000001','Workflow owner','Workflow owner','workflow-owner@example.test','1d000000-0000-0000-0000-000000000002','1d000000-0000-0000-0000-000000000002');
insert into public.teams(id,name,join_code,created_by) values ('3d000000-0000-0000-0000-000000000001','Workflow Team','WORK0001','2d000000-0000-0000-0000-000000000001');
insert into public.billing_customers(id,owner_user_id,customer_type,team_id,billing_name,billing_email) values ('4d000000-0000-0000-0000-000000000001','1d000000-0000-0000-0000-000000000002','team','3d000000-0000-0000-0000-000000000001','Workflow payer','workflow-owner@example.test');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1d000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($sql$select public.create_commercial_offering_draft(jsonb_build_object('productId',(select id from public.commercial_products where code='roobin-fines-team'),'code','workflow-team-season','version',1,'customerType','team','billingUnit','team_season','billingInterval','season','currency','GBP','taxBehaviour','provider_calculated','entitlementDefinitionId',(select id from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1),'minQuantity',1,'trialDays',0,'renewalBehaviour','manual','salesChannels',jsonb_build_array('web'),'eligibility','{}'::jsonb),'Workflow offering test')$sql$,'admin creates a structurally complete draft without database editing');
select lives_ok($sql$select public.update_draft_commercial_recovery_policy((select id from public.commercial_offerings where code='workflow-team-season'),'{"retryDays":[1,3],"graceDays":5,"graceAccess":"read_only","permanentFailure":"read_only"}'::jsonb,'Workflow recovery policy')$sql$,'admin versions retry and grace behaviour on the draft offering');
select lives_ok($sql$select public.schedule_commercial_price((select id from public.commercial_offerings where code='workflow-team-season'),1000,'GBP','provider_calculated','GB',now(),null,'retain','Initial workflow price')$sql$,'admin gives the draft a current versioned price');
select lives_ok($sql$select public.publish_commercial_offering((select id from public.commercial_offerings where code='workflow-team-season'),'Workflow publication approval')$sql$,'complete priced draft can be published');
reset role;
select throws_ok($$update public.commercial_offerings set trial_days=99 where code='workflow-team-season'$$,'P0001','Published offerings are immutable; clone another version','published offering fields cannot be rewritten');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1d000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($sql$select public.retire_commercial_offering((select id from public.commercial_offerings where code='workflow-team-season'),'Workflow retirement approval')$sql$,'published offering can be retired through audited operation');
select lives_ok($$select public.create_service_incident('Payment provider test','minor','Checkout is temporarily unavailable.',array['web'],'Workflow incident drill')$$,'admin opens an audited public incident');

select set_config('request.jwt.claims',jsonb_build_object('sub','1d000000-0000-0000-0000-000000000002','role','authenticated','iat',extract(epoch from now())::bigint)::text,true);
select lives_ok($$select public.initiate_billing_contact_transfer('4d000000-0000-0000-0000-000000000001','1d000000-0000-0000-0000-000000000003','Volunteer treasurer handover')$$,'current recently-authenticated billing owner nominates replacement');
reset role;
select set_config('test.transfer_id',(select id::text from public.billing_contact_transfers where billing_customer_id='4d000000-0000-0000-0000-000000000001'),true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1d000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select lives_ok($sql$select public.accept_billing_contact_transfer(current_setting('test.transfer_id')::uuid)$sql$,'nominated verified replacement accepts transfer');
reset role;
select is((select owner_user_id from public.billing_customers where id='4d000000-0000-0000-0000-000000000001'),'1d000000-0000-0000-0000-000000000003'::uuid,'billing ownership transfers without replacing the customer');
select is((select role from public.billing_customer_contacts where billing_customer_id='4d000000-0000-0000-0000-000000000001' and user_id='1d000000-0000-0000-0000-000000000002'),'administrator','previous billing owner remains a confirmed administrator');
select is((select count(*)::integer from public.commercial_audit_log where action like 'billing_transfer.%'),2,'both transfer steps are audited');
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','1d000000-0000-0000-0000-000000000003','role','authenticated','iat',extract(epoch from now())::bigint)::text,true);
select lives_ok($$select public.update_billing_customer_profile('4d000000-0000-0000-0000-000000000001','Workflow Club','accounts@example.test',jsonb_build_object('line1','1 League Street','city','Wolverhampton','postcode','WV1 1AA','countryCode','GB'),'','Verified payer update')$$,'recently authenticated billing owner updates the separate billing profile');
select lives_ok($$select public.manage_billing_customer_contact('4d000000-0000-0000-0000-000000000001','workflow-owner@example.test','viewer','grant','Treasurer read access')$$,'billing owner grants a verified billing-only contact');
reset role;
select is((select role from public.billing_customer_contacts where billing_customer_id='4d000000-0000-0000-0000-000000000001' and user_id='1d000000-0000-0000-0000-000000000002'),'viewer','billing contact role changes without changing team authority');
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','1d000000-0000-0000-0000-000000000001','role','authenticated','iat',extract(epoch from now())::bigint)::text,true);
select lives_ok($$select public.create_billing_recovery_request('4d000000-0000-0000-0000-000000000001','workflow-owner@example.test','SUP-RECOVERY-001','Previous treasurer unavailable with verified evidence')$$,'platform administrator records evidence-backed high-risk recovery');
reset role;
select set_config('test.recovery_id',(select id::text from public.billing_recovery_requests where billing_customer_id='4d000000-0000-0000-0000-000000000001'),true);
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','1d000000-0000-0000-0000-000000000001','role','authenticated','iat',extract(epoch from now())::bigint)::text,true);
select throws_ok($sql$select public.approve_billing_recovery_request(current_setting('test.recovery_id')::uuid,'Independent approval evidence reviewed')$sql$,'P0001','A different platform administrator must approve recovery','requesting administrator cannot self-approve recovery');
select set_config('request.jwt.claims',jsonb_build_object('sub','1d000000-0000-0000-0000-000000000004','role','authenticated','iat',extract(epoch from now())::bigint)::text,true);
select lives_ok($sql$select public.approve_billing_recovery_request(current_setting('test.recovery_id')::uuid,'Independent approval evidence reviewed')$sql$,'different recently-authenticated administrator approves recovery');
reset role;
select is((select count(*)::integer from public.commercial_notification_deliveries where notification_type in ('billing_transfer_requested','billing_transfer_completed','billing_recovery_completed')),6,'both reachable parties receive queued handover and recovery confirmations');

insert into public.team_playing_cycles(id,team_id,name,sport,starts_on,ends_on,status) values ('5d000000-0000-0000-0000-000000000001','3d000000-0000-0000-0000-000000000001','Correction Cycle','pool',current_date,current_date+90,'active');
insert into public.team_season_entitlements(id,team_id,playing_cycle_id,entitlement_definition_id,state,valid_from,valid_until,source) select '6d000000-0000-0000-0000-000000000001','3d000000-0000-0000-0000-000000000001','5d000000-0000-0000-0000-000000000001',id,'trial',now(),now()+interval '14 days','trial' from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1d000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((public.correct_team_cycle_access_batch('7d000000-0000-0000-0000-000000000001',array['6d000000-0000-0000-0000-000000000001'::uuid],'active',null,'Approved batch correction test',true)->>'count')::integer,1,'bulk correction returns a bounded non-mutating preview');
select is((public.correct_team_cycle_access_batch('7d000000-0000-0000-0000-000000000001',array['6d000000-0000-0000-0000-000000000001'::uuid],'active',null,'Approved batch correction test',false)->>'count')::integer,1,'previewed bulk correction executes');
select is((public.correct_team_cycle_access_batch('7d000000-0000-0000-0000-000000000001',array['6d000000-0000-0000-0000-000000000001'::uuid],'active',null,'Approved batch correction test',false)->>'count')::integer,1,'replayed operation returns the completed idempotent result');
reset role;

select * from finish();
rollback;
