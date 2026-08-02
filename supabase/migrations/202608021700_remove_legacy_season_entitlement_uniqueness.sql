alter table public.team_season_entitlements drop constraint if exists team_season_entitlements_team_id_season_id_entitlement_defi_key;

comment on constraint one_entitlement_per_cycle_source on public.team_season_entitlements is 'One entitlement provenance per team playing cycle and definition. Playing cycle is authoritative; legacy nullable season_id must not collapse distinct cycle grants.';
