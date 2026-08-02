create or replace function public.accept_team_invite_by_token(invite_token text)
returns public.teams
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_email text := lower(coalesce(auth.jwt()->>'email', ''));
  actor_player_id uuid := public.current_player_id();
  target_invite public.team_invites;
  accepted_team public.teams;
begin
  if auth.uid() is null or actor_email = '' or actor_player_id is null then
    raise exception 'Authenticated player profile required';
  end if;
  select * into target_invite from public.team_invites ti
  where ti.token = invite_token and ti.status = 'pending' for update;
  if target_invite.id is null or target_invite.expires_at <= now()
     or lower(target_invite.email) <> actor_email then
    raise exception 'Invitation is invalid or unavailable';
  end if;

  insert into public.team_memberships (team_id, player_id, role, status, invited_at, joined_at)
  values (target_invite.team_id, actor_player_id, 'member', 'active', target_invite.created_at, now())
  on conflict (team_id, player_id) do update
  set status = 'active', joined_at = now();

  update public.team_invites set status = 'accepted', player_id = actor_player_id
  where id = target_invite.id;
  select * into accepted_team from public.teams where id = target_invite.team_id;
  return accepted_team;
end;
$$;

revoke all on function public.accept_team_invite_by_token(text) from public, anon;
grant execute on function public.accept_team_invite_by_token(text) to authenticated;
notify pgrst, 'reload schema';
