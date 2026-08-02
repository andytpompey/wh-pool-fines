create or replace view public.team_cycle_access_summary
with (security_invoker = true) as
select c.id, c.team_id, c.name, c.sport, c.starts_on, c.ends_on, c.status,
  case
    when e.revoked_at is not null then 'revoked'
    when e.id is null then 'missing'
    when now() <= e.valid_until then e.state::text
    when e.grace_until is not null and now() <= e.grace_until then 'grace'
    else 'expired'
  end as entitlement_state,
  e.valid_until as entitlement_valid_until
from public.team_playing_cycles c
left join lateral (
  select candidate.* from public.team_season_entitlements candidate
  where candidate.team_id = c.team_id and candidate.playing_cycle_id = c.id
  order by (candidate.revoked_at is null) desc, candidate.valid_until desc limit 1
) e on true;

grant select on public.team_cycle_access_summary to authenticated;
