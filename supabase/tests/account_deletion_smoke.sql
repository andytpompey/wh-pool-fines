begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('16000000-0000-0000-0000-000000000001', 'blocked@example.test', now(), now(), now()),
  ('16000000-0000-0000-0000-000000000002', 'teammate@example.test', now(), now(), now()),
  ('16000000-0000-0000-0000-000000000003', 'departing@example.test', now(), now(), now()),
  ('16000000-0000-0000-0000-000000000004', 'solo@example.test', now(), now(), now());
insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('26000000-0000-0000-0000-000000000001', 'Blocked Captain', 'Blocked Captain', 'blocked@example.test', '16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000001'),
  ('26000000-0000-0000-0000-000000000002', 'Teammate', 'Teammate', 'teammate@example.test', '16000000-0000-0000-0000-000000000002', '16000000-0000-0000-0000-000000000002'),
  ('26000000-0000-0000-0000-000000000003', 'Departing Player', 'Departing Player', 'departing@example.test', '16000000-0000-0000-0000-000000000003', '16000000-0000-0000-0000-000000000003'),
  ('26000000-0000-0000-0000-000000000004', 'Solo Captain', 'Solo Captain', 'solo@example.test', '16000000-0000-0000-0000-000000000004', '16000000-0000-0000-0000-000000000004');
insert into public.teams (id, name, join_code, created_by)
values
  ('36000000-0000-0000-0000-000000000001', 'Shared Pool Team', 'DELTEST1', '26000000-0000-0000-0000-000000000001'),
  ('36000000-0000-0000-0000-000000000002', 'Solo Pool Team', 'DELTEST2', '26000000-0000-0000-0000-000000000004');
insert into public.team_memberships (id, team_id, player_id, role, status)
values
  ('66000000-0000-0000-0000-000000000001', '36000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('66000000-0000-0000-0000-000000000002', '36000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('66000000-0000-0000-0000-000000000003', '36000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('66000000-0000-0000-0000-000000000004', '36000000-0000-0000-0000-000000000002', '26000000-0000-0000-0000-000000000004', 'captain', 'active');
insert into public.matches (id, team_id, date, opponent, submitted)
values
  ('46000000-0000-0000-0000-000000000001', '36000000-0000-0000-0000-000000000001', '2026-08-01', 'Other Club', true),
  ('46000000-0000-0000-0000-000000000002', '36000000-0000-0000-0000-000000000002', '2026-08-01', 'Solo History', true);
insert into public.fines (id, match_id, player_id, player_name, fine_name, cost, paid)
values
  ('56000000-0000-0000-0000-000000000001', '46000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000003', 'Departing Player', 'Test fine', 1.00, false),
  ('56000000-0000-0000-0000-000000000002', '46000000-0000-0000-0000-000000000002', '26000000-0000-0000-0000-000000000004', 'Solo Captain', 'Solo fine', 1.00, false);
insert into public.subs (id, match_id, player_id, player_name, amount, paid)
values ('57000000-0000-0000-0000-000000000001', '46000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000003', 'Departing Player', 0.50, false);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '16000000-0000-0000-0000-000000000001', 'role', 'authenticated',
  'email', 'blocked@example.test', 'iat', extract(epoch from now())::bigint
)::text, true);

select is(
  jsonb_array_length(public.account_deletion_preflight()->'captaincyBlockers'),
  1,
  'preflight identifies a captaincy transfer blocker'
);
select throws_ok(
  $$select public.delete_current_account()$$,
  'P0001',
  'Transfer captaincy before deleting your account: Shared Pool Team',
  'captain cannot delete while other active members remain'
);
reset role;
select ok(
  exists(select 1 from auth.users where id = '16000000-0000-0000-0000-000000000001'),
  'blocked deletion leaves the identity intact'
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '16000000-0000-0000-0000-000000000003', 'role', 'authenticated',
  'email', 'departing@example.test', 'iat', extract(epoch from now())::bigint
)::text, true);
select is(
  (public.account_deletion_preflight()->>'historicalFineCount')::integer,
  1,
  'preflight reports retained fine history'
);
select lives_ok(
  $$select public.delete_current_account()$$,
  'member account deletion completes atomically'
);
reset role;
select ok(
  not exists(select 1 from auth.users where id = '16000000-0000-0000-0000-000000000003'),
  'authentication identity is deleted'
);
select ok(
  not exists(select 1 from public.players where id = '26000000-0000-0000-0000-000000000003'),
  'personal player profile is deleted'
);
select is(
  (select player_id from public.fines where id = '56000000-0000-0000-0000-000000000001'),
  null::uuid,
  'retained fine no longer references the deleted profile'
);
select isnt(
  (select player_name from public.fines where id = '56000000-0000-0000-0000-000000000001'),
  'Departing Player',
  'retained fine replaces the personal display name'
);
select is(
  (select player_name from public.fines where id = '56000000-0000-0000-0000-000000000001'),
  (select player_name from public.subs where id = '57000000-0000-0000-0000-000000000001'),
  'one stable anonymous alias is used across the team ledger'
);
select ok(
  exists (
    select 1
      from public.sport_anonymous_alias_terms a
      cross join public.sport_anonymous_alias_terms n
     where a.sport_key = 'pool' and a.term_kind = 'adjective'
       and n.sport_key = 'pool' and n.term_kind = 'noun'
       and a.term || ' ' || n.term = (
         select player_name from public.fines where id = '56000000-0000-0000-0000-000000000001'
       )
  ),
  'anonymous alias comes from the team sport vocabulary'
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '16000000-0000-0000-0000-000000000004', 'role', 'authenticated',
  'email', 'solo@example.test', 'iat', extract(epoch from now())::bigint
)::text, true);
select is(
  jsonb_array_length(public.account_deletion_preflight()->'teamsDeletedWithAccount'),
  1,
  'preflight identifies a sole-member team that will close'
);
select lives_ok(
  $$select public.delete_current_account()$$,
  'sole-member captain can delete their account and team'
);
reset role;
select ok(
  not exists(select 1 from public.teams where id = '36000000-0000-0000-0000-000000000002'),
  'sole-member team and its history are deleted'
);
select ok(
  not exists(select 1 from auth.users where id = '16000000-0000-0000-0000-000000000004'),
  'sole captain authentication identity is deleted'
);

select * from finish();
rollback;
