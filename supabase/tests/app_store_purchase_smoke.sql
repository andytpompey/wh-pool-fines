begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id,email,email_confirmed_at,created_at,updated_at) values
 ('1a000000-0000-0000-0000-000000000001','store-captain@example.test',now(),now(),now()),
 ('1a000000-0000-0000-0000-000000000002','store-member@example.test',now(),now(),now());
insert into public.players (id,name,display_name,email,user_id,auth_user_id) values
 ('2a000000-0000-0000-0000-000000000001','Captain','Captain','store-captain@example.test','1a000000-0000-0000-0000-000000000001','1a000000-0000-0000-0000-000000000001'),
 ('2a000000-0000-0000-0000-000000000002','Member','Member','store-member@example.test','1a000000-0000-0000-0000-000000000002','1a000000-0000-0000-0000-000000000002');
insert into public.teams (id,name,join_code,created_by) values ('3a000000-0000-0000-0000-000000000001','Store Team','STORE001','2a000000-0000-0000-0000-000000000001');
insert into public.team_memberships (team_id,player_id,role,status) values
 ('3a000000-0000-0000-0000-000000000001','2a000000-0000-0000-0000-000000000001','captain','active'),
 ('3a000000-0000-0000-0000-000000000001','2a000000-0000-0000-0000-000000000002','member','active');
insert into public.team_playing_cycles (id,team_id,name,starts_on,ends_on,status) values
 ('4a000000-0000-0000-0000-000000000001','3a000000-0000-0000-0000-000000000001','2026/27','2026-09-01','2027-05-31','planned');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"1a000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.begin_app_store_team_purchase('3a000000-0000-0000-0000-000000000001','4a000000-0000-0000-0000-000000000001')$$,'P0001','Team leadership access required','ordinary member cannot start team purchase');

select set_config('request.jwt.claims','{"sub":"1a000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((public.begin_app_store_team_purchase('3a000000-0000-0000-0000-000000000001','4a000000-0000-0000-0000-000000000001')->>'productId'),'com.roobin.fines.teamseason','captain receives server-owned StoreKit product');
reset role;
select is((select count(*)::integer from public.app_store_purchase_contexts),1,'server records exactly one short-lived purchase context');
select is((select playing_cycle_id from public.app_store_purchase_contexts limit 1),'4a000000-0000-0000-0000-000000000001'::uuid,'purchase context binds the paid playing cycle');
select is((select owner_user_id from public.app_store_purchase_contexts limit 1),'1a000000-0000-0000-0000-000000000001'::uuid,'purchase context binds the authenticated payer');
select ok(not has_table_privilege('authenticated','public.app_store_transactions','insert'),'client cannot insert a claimed Apple transaction');
select ok(not has_table_privilege('authenticated','public.app_store_purchase_contexts','select'),'client cannot enumerate purchase contexts');

select * from finish();
rollback;
