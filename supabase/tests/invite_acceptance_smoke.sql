begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('14000000-0000-0000-0000-000000000001', 'inviter@example.test', now(), now(), now()),
  ('14000000-0000-0000-0000-000000000002', 'invitee@example.test', now(), now(), now());
insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('24000000-0000-0000-0000-000000000001', 'Inviter', 'Inviter', 'inviter@example.test', '14000000-0000-0000-0000-000000000001', '14000000-0000-0000-0000-000000000001'),
  ('24000000-0000-0000-0000-000000000002', 'Invitee', 'Invitee', 'invitee@example.test', '14000000-0000-0000-0000-000000000002', '14000000-0000-0000-0000-000000000002');
insert into public.teams (id, name, join_code, created_by)
values ('34000000-0000-0000-0000-000000000001', 'Invite Team', 'INVTEST1', '24000000-0000-0000-0000-000000000001');
insert into public.team_memberships (id, team_id, player_id, role, status)
values ('64000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', '24000000-0000-0000-0000-000000000001', 'captain', 'active');
insert into public.team_invites (id, team_id, email, token, status, invited_by_player_id, expires_at)
values ('74000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', 'invitee@example.test', 'invite-token-test', 'pending', '24000000-0000-0000-0000-000000000001', now() + interval '1 day');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"14000000-0000-0000-0000-000000000002","role":"authenticated","email":"invitee@example.test"}', true);

select lives_ok(
  $$select public.accept_team_invite_by_token('invite-token-test')$$,
  'invite acceptance creates an active membership'
);
select is(
  (select status from public.team_memberships where team_id = '34000000-0000-0000-0000-000000000001' and player_id = '24000000-0000-0000-0000-000000000002'),
  'active',
  'invitee membership is active'
);
select is(
  (select role from public.team_memberships where team_id = '34000000-0000-0000-0000-000000000001' and player_id = '24000000-0000-0000-0000-000000000002'),
  'member',
  'invitee receives member role'
);
select is(
  (select status from public.team_invites where id = '74000000-0000-0000-0000-000000000001'),
  'accepted',
  'invite is marked accepted'
);

select * from finish();
rollback;
