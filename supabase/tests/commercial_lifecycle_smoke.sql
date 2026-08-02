begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select has_table('public','commercial_notification_deliveries','notification delivery ledger exists');
select has_view('public','commercial_notifications_due','notification due view exists');
select ok(not has_table_privilege('authenticated','public.commercial_notification_deliveries','select'),'clients cannot read recipient delivery metadata');
select ok(not has_function_privilege('authenticated','public.record_discount_redemption_from_provider(text,uuid,uuid,integer,integer,text,text)','execute'),'clients cannot claim discount redemption');

insert into auth.users(id,email,email_confirmed_at,created_at,updated_at) values ('1b000000-0000-0000-0000-000000000001','lifecycle-captain@example.test',now(),now(),now());
insert into public.players(id,name,display_name,email,user_id,auth_user_id) values ('2b000000-0000-0000-0000-000000000001','Captain','Captain','lifecycle-captain@example.test','1b000000-0000-0000-0000-000000000001','1b000000-0000-0000-0000-000000000001');
insert into public.teams(id,name,join_code,created_by) values ('3b000000-0000-0000-0000-000000000001','Lifecycle Team','LIFE0001','2b000000-0000-0000-0000-000000000001');
insert into public.team_memberships(team_id,player_id,role,status) values ('3b000000-0000-0000-0000-000000000001','2b000000-0000-0000-0000-000000000001','captain','active');
insert into public.team_playing_cycles(id,team_id,name,starts_on,ends_on,status) values ('4b000000-0000-0000-0000-000000000001','3b000000-0000-0000-0000-000000000001','Reminder Cycle',current_date-30,current_date+14,'active');
insert into public.seasons(id,team_id,name,type,playing_cycle_id) values ('5b000000-0000-0000-0000-000000000001','3b000000-0000-0000-0000-000000000001','Reminder League','League','4b000000-0000-0000-0000-000000000001');
insert into public.team_season_entitlements(team_id,season_id,playing_cycle_id,entitlement_definition_id,state,valid_from,valid_until,source,source_reference)
select '3b000000-0000-0000-0000-000000000001','5b000000-0000-0000-0000-000000000001','4b000000-0000-0000-0000-000000000001',id,'trial',now()-interval '30 days',(current_date+14)::timestamptz,'trial','test:lifecycle' from public.entitlement_definitions where code='fines-team-standard' and state='published' order by version desc limit 1;

select is((select count(*)::integer from public.commercial_notifications_due where days_before=14),1,'captain trial receives the configured 14-day reminder');
select is((select recipient from public.commercial_notifications_due where days_before=14),'lifecycle-captain@example.test','trial reminder targets captain rather than ordinary members');
insert into public.commercial_notification_deliveries(notification_key,notification_type,entitlement_id,recipient_digest,status,scheduled_for) select notification_key,notification_type,entitlement_id,'digest','delivered',now() from public.commercial_notifications_due where days_before=14;
select is((select count(*)::integer from public.commercial_notifications_due where days_before=14),0,'delivered reminder is not queued twice');

insert into public.commercial_discounts(id,name,discount_type,percentage,valid_from,state) values ('6b000000-0000-0000-0000-000000000001','Lifecycle discount','percentage',10,now()-interval '1 day','published');
insert into public.commercial_discount_codes(discount_id,code_digest,code_hint,max_redemptions,provider_reference) values ('6b000000-0000-0000-0000-000000000001','irreversible-digest','LI…FE',1,'promo_lifecycle');
select ok((select code_digest='irreversible-digest' and code_hint='LI…FE' from public.commercial_discount_codes where provider_reference='promo_lifecycle'),'stored code is digest plus non-sensitive hint');
select throws_ok($$insert into public.commercial_discount_codes(discount_id,code_digest,code_hint,max_redemptions,provider_reference) values ('6b000000-0000-0000-0000-000000000001','another-digest','OT…ER',1,'promo_lifecycle')$$,'23505',null,'provider promotion references cannot be duplicated');

insert into public.commercial_offerings(product_id,code,version,customer_type,billing_unit,billing_interval,currency,tax_behaviour,entitlement_definition_id,min_quantity,trial_days,renewal_behaviour,sales_channels,eligibility,state,lifecycle_policy)
select product_id,'lifecycle-read-only',1,customer_type,billing_unit,billing_interval,currency,tax_behaviour,entitlement_definition_id,min_quantity,trial_days,renewal_behaviour,sales_channels,eligibility,'published','{"retryDays":[1],"graceDays":7,"graceAccess":"read_only","permanentFailure":"read_only"}'::jsonb from public.commercial_offerings where code='team-season-standard' and state='published' order by version desc limit 1;
insert into public.billing_customers(id,owner_user_id,customer_type,team_id,billing_email) values ('7b000000-0000-0000-0000-000000000001','1b000000-0000-0000-0000-000000000001','team','3b000000-0000-0000-0000-000000000001','lifecycle-captain@example.test');
insert into public.commercial_subscriptions(id,billing_customer_id,offering_id,price_version_id,team_id,playing_cycle_id,provider,provider_subscription_id,state,current_period_start,current_period_end)
select '8b000000-0000-0000-0000-000000000001','7b000000-0000-0000-0000-000000000001',o.id,(select id from public.commercial_price_versions order by created_at limit 1),'3b000000-0000-0000-0000-000000000001','4b000000-0000-0000-0000-000000000001','stripe','sub_read_only_grace','past_due',now()-interval '30 days',now() from public.commercial_offerings o where o.code='lifecycle-read-only';
update public.team_season_entitlements set subscription_id='8b000000-0000-0000-0000-000000000001',state='grace',grace_until=valid_until+interval '7 days' where team_id='3b000000-0000-0000-0000-000000000001';
update public.commercial_settings set value=value||'{"mode":"enforce"}'::jsonb where key='entitlement_enforcement';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1b000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select ok(not public.commercial_team_write_allowed('3b000000-0000-0000-0000-000000000001','team_management'),'read-only payment grace preserves reads but denies operational write capability');
reset role;

select * from finish();
rollback;
