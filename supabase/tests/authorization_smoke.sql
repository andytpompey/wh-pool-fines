begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('10000000-0000-0000-0000-000000000001', 'captain@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000002', 'member@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000003', 'outsider@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000004', 'invited@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000005', 'vice@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000006', 'pending@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000007', 'removed@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000008', 'platform@example.test', now(), now(), now()),
  ('10000000-0000-0000-0000-000000000009', 'conflict@example.test', now(), now(), now());

insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('20000000-0000-0000-0000-000000000001', 'Captain', 'Captain', 'captain@example.test', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Member', 'Member', 'member@example.test', '10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002'),
  ('20000000-0000-0000-0000-000000000003', 'Outsider', 'Outsider', 'conflict@example.test', '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003'),
  ('20000000-0000-0000-0000-000000000004', 'Invited Player', 'Invited Player', 'invited@example.test', null, null),
  ('20000000-0000-0000-0000-000000000005', 'Vice', 'Vice', 'vice@example.test', '10000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005'),
  ('20000000-0000-0000-0000-000000000006', 'Pending', 'Pending', 'pending@example.test', '10000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000006'),
  ('20000000-0000-0000-0000-000000000007', 'Removed', 'Removed', 'removed@example.test', '10000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000007'),
  ('20000000-0000-0000-0000-000000000008', 'Platform Admin', 'Platform Admin', 'platform@example.test', '10000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000008');

insert into public.teams (id, name, join_code, created_by)
values (
  '30000000-0000-0000-0000-000000000001',
  'Authorization Test Team',
  'AUTHTEST',
  '20000000-0000-0000-0000-000000000001'
);

insert into public.team_memberships (team_id, player_id, role, status)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000005', 'vice_captain', 'active'),
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000006', 'member', 'invited'),
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000007', 'member', 'removed');

insert into public.app_users (id, is_platform_admin)
values ('10000000-0000-0000-0000-000000000008', true);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","email":"captain@example.test"}',
  true
);

select ok(
  public.can_manage_team_operations('30000000-0000-0000-0000-000000000001'),
  'captain can manage team operations'
);

select lives_ok(
  $$insert into public.fine_types (name, cost, team_id)
    values ('Captain fine', 1.00, '30000000-0000-0000-0000-000000000001')$$,
  'captain can create an operational record'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated","email":"member@example.test"}',
  true
);

select ok(
  not public.can_manage_team_operations('30000000-0000-0000-0000-000000000001'),
  'ordinary member cannot manage team operations'
);

select throws_ok(
  $$insert into public.fine_types (name, cost, team_id)
    values ('Member fine', 1.00, '30000000-0000-0000-0000-000000000001')$$,
  '42501',
  'new row violates row-level security policy for table "fine_types"',
  'ordinary member cannot bypass the client and write directly'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated","email":"outsider@example.test"}',
  true
);

select is(
  (select count(*)::integer from public.teams where id = '30000000-0000-0000-0000-000000000001'),
  0,
  'cross-team user cannot read the team'
);

select throws_ok(
  $$insert into public.fine_types (name, cost, team_id)
    values ('Cross-team fine', 1.00, '30000000-0000-0000-0000-000000000001')$$,
  '42501',
  'new row violates row-level security policy for table "fine_types"',
  'cross-team user cannot mutate operational records'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000005","role":"authenticated","email":"vice@example.test"}',
  true
);

select ok(
  public.can_manage_team_operations('30000000-0000-0000-0000-000000000001'),
  'vice-captain can manage team operations'
);

select lives_ok(
  $$insert into public.fine_types (name, cost, team_id)
    values ('Vice fine', 1.00, '30000000-0000-0000-0000-000000000001')$$,
  'vice-captain can create an operational record'
);

select results_eq(
  $$with changed as (
      update public.team_memberships
         set role = 'captain'
       where team_id = '30000000-0000-0000-0000-000000000001'
         and player_id = '20000000-0000-0000-0000-000000000002'
      returning 1
    )
    select count(*)::integer from changed$$,
  array[0],
  'vice-captain cannot change team roles'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000006","role":"authenticated","email":"pending@example.test"}',
  true
);

select is(
  (select count(*)::integer from public.teams where id = '30000000-0000-0000-0000-000000000001'),
  0,
  'invited member cannot read the team'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000007","role":"authenticated","email":"removed@example.test"}',
  true
);

select is(
  (select count(*)::integer from public.teams where id = '30000000-0000-0000-0000-000000000001'),
  0,
  'removed member cannot read the team'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000008","role":"authenticated","email":"platform@example.test"}',
  true
);

select ok(
  public.can_view_team('30000000-0000-0000-0000-000000000001'),
  'platform administrator can view the team'
);

select lives_ok(
  $$insert into public.fine_types (name, cost, team_id)
    values ('Platform fine', 1.00, '30000000-0000-0000-0000-000000000001')$$,
  'platform administrator can manage operational records'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated","email":"invited@example.test"}',
  true
);

select is(
  (select (public.ensure_current_player('Verified Player', null, 'email')).id),
  '20000000-0000-0000-0000-000000000004'::uuid,
  'verified identity links to the matching unlinked player'
);

select is(
  (select user_id from public.players where id = '20000000-0000-0000-0000-000000000004'),
  '10000000-0000-0000-0000-000000000004'::uuid,
  'identity linking writes the canonical auth user id'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000009","role":"authenticated","email":"conflict@example.test"}',
  true
);

select throws_ok(
  $$select public.ensure_current_player('Conflicting User', null, 'email')$$,
  'P0001',
  'This verified identity is already linked to another account',
  'conflicting identity cannot take over an existing linked player'
);

reset role;

select ok(
  not has_function_privilege('anon', 'public.ensure_current_player(text,text,text)', 'execute'),
  'anonymous clients cannot execute identity linking'
);

select * from finish();
rollback;
