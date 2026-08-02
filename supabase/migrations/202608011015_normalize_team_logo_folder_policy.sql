drop policy if exists "team logos managed by team leaders" on storage.objects;
create policy "team logos managed by team leaders"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.team_memberships tm
    where tm.team_id::text = lower((storage.foldername(name))[1])
      and tm.player_id = public.current_player_id()
      and tm.status = 'active'
      and tm.role in ('captain', 'vice_captain', 'admin')
  )
)
with check (
  bucket_id = 'team-logos'
  and exists (
    select 1
    from public.team_memberships tm
    where tm.team_id::text = lower((storage.foldername(name))[1])
      and tm.player_id = public.current_player_id()
      and tm.status = 'active'
      and tm.role in ('captain', 'vice_captain', 'admin')
  )
);
