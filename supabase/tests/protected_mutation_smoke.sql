begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

create temporary table test_grants (name text primary key, token uuid);
grant all on table test_grants to authenticated;

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values ('12000000-0000-0000-0000-000000000001', 'mutation-captain@example.test', now(), now(), now());

insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values ('22000000-0000-0000-0000-000000000001', 'Mutation Captain', 'Mutation Captain', 'mutation-captain@example.test', '12000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000001');

insert into public.teams (id, name, join_code, created_by)
values
  ('32000000-0000-0000-0000-000000000001', 'Mutation Team', 'MUTATE01', '22000000-0000-0000-0000-000000000001'),
  ('32000000-0000-0000-0000-000000000002', 'Other Team', 'MUTATE02', '22000000-0000-0000-0000-000000000001');

insert into public.team_memberships (team_id, player_id, role, status)
values
  ('32000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('32000000-0000-0000-0000-000000000002', '22000000-0000-0000-0000-000000000001', 'captain', 'active');

insert into public.matches (id, date, team_id, submitted)
values
  ('42000000-0000-0000-0000-000000000001', current_date, '32000000-0000-0000-0000-000000000001', true),
  ('42000000-0000-0000-0000-000000000002', current_date, '32000000-0000-0000-0000-000000000002', true);

insert into public.fines (id, match_id, player_id, player_name, fine_name, cost)
values
  ('52000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000001', 'Mutation Captain', 'Delete me', 1),
  ('52000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000002', '22000000-0000-0000-0000-000000000001', 'Mutation Captain', 'Other team fine', 1);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"12000000-0000-0000-0000-000000000001","role":"authenticated","email":"mutation-captain@example.test"}',
  true
);

select public.set_team_unlock_code('32000000-0000-0000-0000-000000000001', '135790');
select public.set_team_unlock_code('32000000-0000-0000-0000-000000000002', '135790');

select results_eq(
  $$with removed as (
      delete from public.fines
       where id = '52000000-0000-0000-0000-000000000001'
      returning 1
    )
    select count(*)::integer from removed$$,
  array[0],
  'direct protected delete is denied by RLS'
);

select throws_ok(
  $$update public.matches
       set submitted = false
     where id = '42000000-0000-0000-0000-000000000001'$$,
  'P0001',
  'Unlocking a submitted match requires a protected-action grant',
  'direct submitted-to-unlocked transition is rejected'
);

insert into test_grants (name, token)
select 'fine-delete', (public.verify_team_unlock_code(
  '32000000-0000-0000-0000-000000000001',
  'delete_fine_entry',
  '135790'
) ->> 'grantToken')::uuid;

select lives_ok(
  $$select public.execute_protected_action(
      (select token from test_grants where name = 'fine-delete'),
      'fine',
      '52000000-0000-0000-0000-000000000001'
    )$$,
  'valid grant and deletion execute atomically'
);

select is(
  (select count(*)::integer from public.fines where id = '52000000-0000-0000-0000-000000000001'),
  0,
  'protected target was deleted'
);

select throws_ok(
  $$select public.execute_protected_action(
      (select token from test_grants where name = 'fine-delete'),
      'fine',
      '52000000-0000-0000-0000-000000000001'
    )$$,
  'P0001',
  'Grant is invalid, expired, used, or for another action',
  'grant replay is rejected'
);

insert into test_grants (name, token)
select 'wrong-action', (public.verify_team_unlock_code(
  '32000000-0000-0000-0000-000000000001',
  'delete_match',
  '135790'
) ->> 'grantToken')::uuid;

select throws_ok(
  $$select public.execute_protected_action(
      (select token from test_grants where name = 'wrong-action'),
      'fine',
      '52000000-0000-0000-0000-000000000002'
    )$$,
  'P0001',
  'Grant is invalid, expired, used, or for another action',
  'grant cannot authorize a different action'
);

insert into test_grants (name, token)
select 'cross-team', (public.verify_team_unlock_code(
  '32000000-0000-0000-0000-000000000001',
  'delete_fine_entry',
  '135790'
) ->> 'grantToken')::uuid;

select throws_ok(
  $$select public.execute_protected_action(
      (select token from test_grants where name = 'cross-team'),
      'fine',
      '52000000-0000-0000-0000-000000000002'
    )$$,
  'P0001',
  'Protected target was not found or cannot be changed',
  'grant cannot mutate a different team'
);

insert into test_grants (name, token)
select 'unlock', (public.verify_team_unlock_code(
  '32000000-0000-0000-0000-000000000001',
  'unlock_match',
  '135790'
) ->> 'grantToken')::uuid;

select lives_ok(
  $$select public.execute_protected_action(
      (select token from test_grants where name = 'unlock'),
      'match_unlock',
      '42000000-0000-0000-0000-000000000001'
    )$$,
  'match unlock consumes its matching grant'
);

select is(
  (select submitted from public.matches where id = '42000000-0000-0000-0000-000000000001'),
  false,
  'match was unlocked'
);

reset role;

select is(
  (
    select count(*)::integer
      from public.audit_logs
     where team_id = '32000000-0000-0000-0000-000000000001'
       and action in ('protected_record.deleted', 'protected_record.reversed')
  ),
  2,
  'each successful mutation has one atomic audit record'
);

select * from finish();
rollback;

