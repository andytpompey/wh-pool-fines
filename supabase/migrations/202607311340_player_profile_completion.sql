-- Track explicit profile completion separately from automatically derived names.
alter table public.players
  add column if not exists profile_completed_at timestamptz;

create or replace function public.update_current_player_profile(
  profile_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_player public.players;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if profile_display_name is null or btrim(profile_display_name) = '' then
    raise exception 'Display name is required';
  end if;

  update public.players
     set display_name = btrim(profile_display_name),
         name = btrim(profile_display_name),
         profile_completed_at = now()
   where user_id = auth.uid()
   returning * into updated_player;

  if updated_player.id is null then
    raise exception 'Authenticated player profile not found';
  end if;

  return jsonb_build_object(
    'id', updated_player.id,
    'display_name', updated_player.display_name,
    'profile_completed_at', updated_player.profile_completed_at
  );
end;
$$;

revoke all on function public.update_current_player_profile(text) from public, anon;
grant execute on function public.update_current_player_profile(text) to authenticated;

notify pgrst, 'reload schema';
