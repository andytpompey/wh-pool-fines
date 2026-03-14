-- Fix infinite recursion in players RLS policies.
-- The previous "own profile" policy queried `players` from within a `players`
-- policy expression, which can recurse under RLS evaluation.

create or replace function current_player_id_for_auth_user()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from players p
  where p.user_id = auth.uid()
  order by p.created_at asc
  limit 1;
$$;

revoke all on function current_player_id_for_auth_user() from public;
grant execute on function current_player_id_for_auth_user() to anon, authenticated;

drop policy if exists "own profile" on players;

create policy "own profile" on players
for select to authenticated
using (
  user_id = auth.uid()
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  or exists (
    select 1
    from team_memberships mine
    join team_memberships theirs
      on theirs.team_id = mine.team_id
     and theirs.player_id = players.id
    where mine.player_id = current_player_id_for_auth_user()
      and mine.status = 'active'
      and theirs.status = 'active'
  )
);
