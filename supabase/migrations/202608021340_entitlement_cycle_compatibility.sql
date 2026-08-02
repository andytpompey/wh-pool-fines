-- Preserve season-based administrative and older-client contracts while the
-- playing-cycle identifier becomes the commercial authority.
create or replace function public.populate_entitlement_playing_cycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.playing_cycle_id is null and new.season_id is not null then
    select s.playing_cycle_id into new.playing_cycle_id
    from public.seasons s
    where s.id = new.season_id and s.team_id = new.team_id;
  end if;
  if new.playing_cycle_id is null then raise exception 'Playing cycle is required'; end if;
  if not exists (select 1 from public.team_playing_cycles c where c.id = new.playing_cycle_id and c.team_id = new.team_id) then
    raise exception 'Playing cycle must belong to the same team';
  end if;
  if new.season_id is not null and not exists (
    select 1 from public.seasons s where s.id = new.season_id and s.team_id = new.team_id and s.playing_cycle_id = new.playing_cycle_id
  ) then raise exception 'Season does not belong to the entitlement playing cycle'; end if;
  return new;
end $$;

create trigger entitlements_populate_playing_cycle
before insert or update of playing_cycle_id, season_id, team_id on public.team_season_entitlements
for each row execute function public.populate_entitlement_playing_cycle();
