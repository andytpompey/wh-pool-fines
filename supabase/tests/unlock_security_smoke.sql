begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('11000000-0000-0000-0000-000000000001', 'unlock-captain@example.test', now(), now(), now()),
  ('11000000-0000-0000-0000-000000000002', 'unlock-member@example.test', now(), now(), now());

insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('21000000-0000-0000-0000-000000000001', 'Unlock Captain', 'Unlock Captain', 'unlock-captain@example.test', '11000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001'),
  ('21000000-0000-0000-0000-000000000002', 'Unlock Member', 'Unlock Member', 'unlock-member@example.test', '11000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000002');

insert into public.teams (id, name, join_code, created_by)
values (
  '31000000-0000-0000-0000-000000000001',
  'Unlock Test Team',
  'UNLOCK01',
  '21000000-0000-0000-0000-000000000001'
);

insert into public.team_memberships (team_id, player_id, role, status)
values
  ('31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000002', 'member', 'active');

select ok(
  not has_column_privilege('authenticated', 'public.teams', 'unlock_code_hash', 'select'),
  'authenticated clients cannot select the unlock hash'
);

select ok(
  not has_column_privilege('authenticated', 'public.teams', 'unlock_code_salt', 'select'),
  'authenticated clients cannot select the unlock salt'
);

select ok(
  not has_table_privilege('authenticated', 'public.unlock_verification_attempts', 'select'),
  'clients cannot inspect durable rate-limit state'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated","email":"unlock-captain@example.test"}',
  true
);

select lives_ok(
  $$select public.set_team_unlock_code(
      '31000000-0000-0000-0000-000000000001',
      '246810'
    )$$,
  'captain can set a server-hashed unlock code'
);

select is(
  (public.verify_team_unlock_code(
    '31000000-0000-0000-0000-000000000001',
    'delete_match',
    '000000'
  ) ->> 'reason'),
  'invalid_code',
  'incorrect code is rejected'
);

select is(
  (public.verify_team_unlock_code(
    '31000000-0000-0000-0000-000000000001',
    'delete_match',
    '246810'
  ) ->> 'authorized')::boolean,
  true,
  'correct code returns an authorization grant'
);

select ok(
  (public.verify_team_unlock_code(
    '31000000-0000-0000-0000-000000000001',
    'delete_match',
    '246810'
  ) ->> 'grantToken') is not null,
  'grant contains an opaque token rather than hash material'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-0000-0000-000000000002","role":"authenticated","email":"unlock-member@example.test"}',
  true
);

select is(
  (public.verify_team_unlock_code(
    '31000000-0000-0000-0000-000000000001',
    'delete_match',
    '246810'
  ) ->> 'reason'),
  'forbidden',
  'ordinary member cannot verify protected actions'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated","email":"unlock-captain@example.test"}',
  true
);

select public.verify_team_unlock_code('31000000-0000-0000-0000-000000000001', 'delete_match', '0');
select public.verify_team_unlock_code('31000000-0000-0000-0000-000000000001', 'delete_match', '0');
select public.verify_team_unlock_code('31000000-0000-0000-0000-000000000001', 'delete_match', '0');
select public.verify_team_unlock_code('31000000-0000-0000-0000-000000000001', 'delete_match', '0');
select public.verify_team_unlock_code('31000000-0000-0000-0000-000000000001', 'delete_match', '0');

select is(
  (public.verify_team_unlock_code(
    '31000000-0000-0000-0000-000000000001',
    'delete_match',
    '246810'
  ) ->> 'reason'),
  'rate_limited',
  'durable server rate limit blocks further attempts'
);

reset role;

select ok(
  not exists (
    select 1
      from public.audit_logs al
     where al.team_id = '31000000-0000-0000-0000-000000000001'
       and al.payload::text like '%246810%'
  ),
  'audit records do not contain the supplied unlock code'
);

select * from finish();
rollback;

