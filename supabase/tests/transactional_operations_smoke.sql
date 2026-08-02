begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id,email,email_confirmed_at,created_at,updated_at)
values ('13000000-0000-0000-0000-000000000001','txn@example.test',now(),now(),now());
insert into public.players (id,name,display_name,email,user_id,auth_user_id)
values
 ('23000000-0000-0000-0000-000000000001','Captain','Captain','txn@example.test','13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-000000000001'),
 ('23000000-0000-0000-0000-000000000002','Next Captain','Next Captain','next@example.test',null,null);
insert into public.teams (id,name,join_code,created_by)
values ('33000000-0000-0000-0000-000000000001','Txn Team','TXNTEAM1','23000000-0000-0000-0000-000000000001');
insert into public.team_memberships (id,team_id,player_id,role,status)
values
 ('63000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000001','captain','active'),
 ('63000000-0000-0000-0000-000000000002','33000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000002','member','active');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-000000000001","role":"authenticated","email":"txn@example.test"}',true);

select lives_ok(
  $$select public.save_match_aggregate(
    '73000000-0000-0000-0000-000000000001',
    '{"id":"43000000-0000-0000-0000-000000000001","teamId":"33000000-0000-0000-0000-000000000001","date":"2026-07-30","submitted":false,"venue":"home","players":[{"playerId":"23000000-0000-0000-0000-000000000001","isDriver":true}],"fines":[{"id":"53000000-0000-0000-0000-000000000001","playerId":"23000000-0000-0000-0000-000000000001","playerName":"Captain","fineName":"Test","cost":1,"paid":false}],"subs":[{"id":"53000000-0000-0000-0000-000000000002","playerId":"23000000-0000-0000-0000-000000000001","playerName":"Captain","amount":0.5,"paid":false}]}'::jsonb
  )$$,
  'match aggregate saves atomically'
);
select is((select count(*)::integer from public.matches where id='43000000-0000-0000-0000-000000000001'),1,'match created once');
select lives_ok(
  $$select public.save_match_aggregate(
    '73000000-0000-0000-0000-000000000001',
    '{"id":"43000000-0000-0000-0000-000000000001","teamId":"33000000-0000-0000-0000-000000000001"}'::jsonb
  )$$,
  'match retry returns stored response'
);
select throws_ok(
  $$select public.save_match_aggregate(
    '73000000-0000-0000-0000-000000000002',
    '{"id":"43000000-0000-0000-0000-000000000001","teamId":"33000000-0000-0000-0000-000000000001","date":"2026-07-30","submitted":false,"venue":"home","players":[],"fines":[],"subs":[]}'::jsonb
  )$$,
  'P0001','Fine deletion requires a protected-action grant',
  'aggregate cannot smuggle a protected fine deletion'
);

select lives_ok(
  $$select public.transfer_team_captain(
    '73000000-0000-0000-0000-000000000003',
    '33000000-0000-0000-0000-000000000001',
    '63000000-0000-0000-0000-000000000002',
    '63000000-0000-0000-0000-000000000001'
  )$$,'captain transfer is atomic'
);
select is((select count(*)::integer from public.team_memberships where team_id='33000000-0000-0000-0000-000000000001' and role='captain'),1,'team has exactly one captain');

-- Restore the original actor as captain for payment authorization.
reset role;
update public.team_memberships set role='captain' where id='63000000-0000-0000-0000-000000000001';
update public.team_memberships set role='member' where id='63000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-000000000001","role":"authenticated","email":"txn@example.test"}',true);

select lives_ok(
  $$select public.update_payment_batch(
    '73000000-0000-0000-0000-000000000004',
    '33000000-0000-0000-0000-000000000001',
    '[{"kind":"fine","id":"53000000-0000-0000-0000-000000000001","paid":true},{"kind":"sub","id":"53000000-0000-0000-0000-000000000002","paid":true}]'::jsonb
  )$$,'payment batch commits together'
);
select ok(
  (select paid from public.fines where id='53000000-0000-0000-0000-000000000001')
  and (select paid from public.subs where id='53000000-0000-0000-0000-000000000002'),
  'all payment items changed'
);
select lives_ok(
  $$select public.update_payment_batch(
    '73000000-0000-0000-0000-000000000004',
    '33000000-0000-0000-0000-000000000001',
    '[]'::jsonb
  )$$,'payment retry is idempotent'
);

select * from finish();
rollback;
