-- Allow unauthenticated self-registration rows in players.
-- Anonymous users can only create unlinked profiles (no auth user IDs).

drop policy if exists "players registration insert" on players;

create policy "players registration insert" on players
for insert to public
with check (
  (
    auth.uid() is null
    and user_id is null
    and auth_user_id is null
  )
  or (
    auth.uid() is not null
    and (user_id is null or user_id = auth.uid())
    and (auth_user_id is null or auth_user_id = auth.uid())
  )
);
