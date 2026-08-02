begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, email_confirmed_at, created_at, updated_at)
values
  ('15000000-0000-0000-0000-000000000001', 'manager@example.test', now(), now(), now()),
  ('15000000-0000-0000-0000-000000000002', 'member@example.test', now(), now(), now());
insert into public.players (id, name, display_name, email, user_id, auth_user_id)
values
  ('25000000-0000-0000-0000-000000000001', 'Manager', 'Manager', 'manager@example.test', '15000000-0000-0000-0000-000000000001', '15000000-0000-0000-0000-000000000001'),
  ('25000000-0000-0000-0000-000000000002', 'Member', 'Member', 'member@example.test', '15000000-0000-0000-0000-000000000002', '15000000-0000-0000-0000-000000000002');
insert into public.teams (id, name, join_code, created_by)
values ('35000000-0000-0000-0000-000000000001', 'Management Team', 'MGTTEST1', '25000000-0000-0000-0000-000000000001');
insert into public.team_memberships (id, team_id, player_id, role, status)
values
  ('65000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', '25000000-0000-0000-0000-000000000001', 'captain', 'active'),
  ('65000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001', '25000000-0000-0000-0000-000000000002', 'member', 'active');
insert into public.team_invites (id, team_id, email, token, status, invited_by_player_id, expires_at)
values ('75000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', 'pending@example.test', 'management-invite', 'pending', '25000000-0000-0000-0000-000000000001', now() + interval '1 day');
insert into public.fine_types (id, team_id, name, cost)
values ('45000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', 'Old fine', 1.00);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"15000000-0000-0000-0000-000000000001","role":"authenticated","email":"manager@example.test"}', true);

select lives_ok(
  $$select public.update_current_player_profile('Updated Manager', false)$$,
  'current user can update their own profile preferences'
);
select is(
  (select display_name from public.players where id = '25000000-0000-0000-0000-000000000001'),
  'Updated Manager',
  'profile display name is updated'
);
select is(
  (select receive_team_notifications from public.players where id = '25000000-0000-0000-0000-000000000001'),
  false,
  'notification preference is updated'
);

select lives_ok(
  $$select public.set_team_member_role('85000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000002', 'vice_captain')$$,
  'captain can promote a member'
);
select is(
  (select role from public.team_memberships where id = '65000000-0000-0000-0000-000000000002'),
  'vice_captain',
  'member role is updated'
);

select lives_ok(
  $$select public.revoke_team_invite('75000000-0000-0000-0000-000000000001')$$,
  'team leader can revoke a pending invitation'
);
select is(
  (select status from public.team_invites where id = '75000000-0000-0000-0000-000000000001'),
  'cancelled',
  'revoked invitation is cancelled'
);

select lives_ok(
  $$select public.update_team_settings('85000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001', 'Renamed Team', true, false, 1.25, null)$$,
  'team leader can update validated team settings'
);
select is(
  (select name from public.teams where id = '35000000-0000-0000-0000-000000000001'),
  'Renamed Team',
  'team name is updated'
);

select lives_ok(
  $$select public.update_team_fine_type('85000000-0000-0000-0000-000000000003', '35000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000001', 'New fine', 2.50)$$,
  'team leader can update a fine type'
);
select is(
  (select name from public.fine_types where id = '45000000-0000-0000-0000-000000000001'),
  'New fine',
  'fine type update persists'
);

select lives_ok(
  $$select public.save_team_season('85000000-0000-0000-0000-000000000004', '35000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', '2026 League', 'League')$$,
  'team leader can create a manual season'
);

select * from finish();
rollback;
