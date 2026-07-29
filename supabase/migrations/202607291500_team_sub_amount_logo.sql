alter table if exists public.teams
  add column if not exists sub_amount numeric(10, 2) not null default 0.50,
  add column if not exists logo_url text;

alter table if exists public.teams
  drop constraint if exists teams_sub_amount_check;

alter table if exists public.teams
  add constraint teams_sub_amount_check check (sub_amount >= 0 and sub_amount <= 100);

drop policy if exists "team scoped write" on public.teams;
create policy "team scoped write"
on public.teams
for update
to authenticated
using (
  exists (
    select 1
    from public.team_memberships tm
    where tm.team_id = teams.id
      and tm.player_id = public.current_player_id()
      and tm.status = 'active'
      and tm.role in ('captain', 'vice_captain', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.team_memberships tm
    where tm.team_id = teams.id
      and tm.player_id = public.current_player_id()
      and tm.status = 'active'
      and tm.role in ('captain', 'vice_captain', 'admin')
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('team-logos', 'team-logos', true, 1048576, array['image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

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
    where tm.team_id::text = (storage.foldername(name))[1]
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
    where tm.team_id::text = (storage.foldername(name))[1]
      and tm.player_id = public.current_player_id()
      and tm.status = 'active'
      and tm.role in ('captain', 'vice_captain', 'admin')
  )
);
