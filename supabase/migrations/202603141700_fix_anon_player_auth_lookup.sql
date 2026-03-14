-- Ensure anon auth flows can look up existing players and register unlinked profiles.
-- This supports pre-OTP checks in the client while keeping authenticated ownership rules.

-- Sign-in/register screens query players by email/mobile before a user session exists.
drop policy if exists "players auth lookup" on players;
create policy "players auth lookup" on players
for select to anon
using (true);

-- Registration before OTP verification creates unlinked player rows.
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
