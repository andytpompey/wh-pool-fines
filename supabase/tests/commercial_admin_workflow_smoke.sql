begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values
 ('1d000000-0000-0000-0000-000000000001','workflow-admin@example.test',now(),now(),now()),
 ('1d000000-0000-0000-0000-000000000002','workflow-owner@example.test',now(),now(),now()),
 ('1d000000-0000-0000-0000-000000000003','workflow-replacement@example.test',now(),now(),now());
insert into public.app_users(id,is_platform_admin) values
 ('1d000000-0000-0000-0000-000000000001',true),('1d000000-0000-0000-0000-000000000002',false),('1d000000-0000-0000-0000-000000000003',false);
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values ('2d000000-0000-0000-0000-000000000001','Workflow owner','Workflow owner','workflow-owner@example.test','1d000000-0000-0000-0000-000000000002','1d000000-0000-0000-0000-000000000002');
insert into public.teams(id,name,join_code,created_by) values ('3d000000-0000-0000-0000-000000000001','Workflow Team','WORK0001','2d000000-0000-0000-0000-000000000001');
insert into public.billing_customers(id,owner_user_id,customer_type,team_id,billing_name,billing_email) values ('4d000000-0000-0000-0000-000000000001','1d000000-0000-0000-0000-000000000002','team','3d000000-0000-0000-0000-000000000001','Workflow payer','workflow-owner@example.test');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1d000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($sql$select public.create_commercial_offering_draft(jsonb_build_object('productId',(select id from public.commercial_products where code='roobin-fines-team'),'code','workflow-team-season','version',1,'customerType','team','billingUnit','team_season','billingInterval','season','currency','GBP','taxBehaviour','provider_calculated','entitlementDefinitionId',(select id from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1),'minQuantity',1,'trialDays',0,'renewalBehaviour','manual','salesChannels',jsonb_build_array('web'),'eligibility','{}'::jsonb),'Workflow offering test')$sql$,'admin creates a structurally complete draft without database editing');
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

select * from finish();
rollback;
