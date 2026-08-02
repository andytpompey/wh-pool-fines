begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('91000000-0000-0000-0000-000000000001', 'captain-comms@example.test', now(), now(), now()),
  ('91000000-0000-0000-0000-000000000002', 'member-comms@example.test', now(), now(), now()),
  ('91000000-0000-0000-0000-000000000003', 'vice-comms@example.test', now(), now(), now());

insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('92000000-0000-0000-0000-000000000001', 'Captain Comms', 'Captain Comms', 'captain-comms@example.test', '91000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001'),
  ('92000000-0000-0000-0000-000000000002', 'Member Comms', 'Member Comms', 'member-comms@example.test', '91000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000002'),
  ('92000000-0000-0000-0000-000000000003', 'Vice Comms', 'Vice Comms', 'vice-comms@example.test', '91000000-0000-0000-0000-000000000003', '91000000-0000-0000-0000-000000000003');

insert into public.teams (id, name, join_code, created_by)
values ('93000000-0000-0000-0000-000000000001', 'Comms Team', 'COMMSTST', '92000000-0000-0000-0000-000000000001');

insert into public.team_memberships (team_id, player_id, role, status)
values
  ('93000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('93000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000002', 'member', 'active'),
  ('93000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000003', 'vice_captain', 'active');

select lives_ok(
  $$select public.prepare_team_invite_as_service(
    '91000000-0000-0000-0000-000000000001',
    '93000000-0000-0000-0000-000000000001',
    'new-player@example.test',
    'New Player'
  )$$,
  'captain can prepare a server-owned invite'
);

select is(
  (select status from public.team_invites where email = 'new-player@example.test'),
  'pending',
  'prepared invite is pending'
);

select ok(
  (select expires_at > now() and expires_at <= now() + interval '7 days 1 minute'
     from public.team_invites where email = 'new-player@example.test'),
  'invite receives a bounded seven-day expiry'
);

select ok(
  (select length(token) = 64 from public.team_invites where email = 'new-player@example.test'),
  'invite token is generated from 32 server-side random bytes'
);

select lives_ok(
  $$select public.prepare_team_invite_as_service(
    '91000000-0000-0000-0000-000000000003',
    '93000000-0000-0000-0000-000000000001',
    'vice-invite@example.test',
    'Vice Invite'
  )$$,
  'vice-captain can prepare an invite'
);

select throws_ok(
  $$select public.prepare_team_invite_as_service(
    '91000000-0000-0000-0000-000000000002',
    '93000000-0000-0000-0000-000000000001',
    'forbidden@example.test',
    'Forbidden'
  )$$,
  'P0001',
  'Only team captains and vice-captains can send invites',
  'ordinary member cannot prepare an invite'
);

create temporary table old_invite_token as
select token from public.team_invites where email = 'new-player@example.test';

select lives_ok(
  $$select public.prepare_team_invite_resend_as_service(
    '91000000-0000-0000-0000-000000000001',
    (select id from public.team_invites where email = 'new-player@example.test')
  )$$,
  'captain can resend a pending invite'
);

select isnt(
  (select token from public.team_invites where email = 'new-player@example.test'),
  (select token from old_invite_token),
  'resend invalidates the previous token'
);

select throws_ok(
  $$select public.prepare_team_invite_as_service(
    '91000000-0000-0000-0000-000000000001',
    '93000000-0000-0000-0000-000000000001',
    'not-an-email',
    'Bad Email'
  )$$,
  'P0001',
  'A valid email address is required',
  'invalid recipient input fails before delivery'
);

select ok(
  not has_function_privilege('authenticated', 'public.prepare_team_invite_as_service(uuid,uuid,text,text)', 'execute')
  and not has_function_privilege('authenticated', 'public.prepare_team_invite(uuid,text,text)', 'execute'),
  'client roles cannot access invite preparation or its secrets'
);

select * from finish();
rollback;
