create or replace function public.has_team_season_capability(target_team_id uuid, target_season_id uuid, capability text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.team_season_entitlements e
    join public.entitlement_definitions d on d.id = e.entitlement_definition_id
      where e.team_id = target_team_id and e.season_id = target_season_id
        and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
        and e.revoked_at is null and now() >= e.valid_from
        and now() <= coalesce(e.grace_until, e.valid_until)
        and e.state in ('trial', 'active', 'grace', 'complimentary')
        and coalesce((d.capabilities ->> capability)::boolean, false)
  );
$$;

revoke all on function public.has_team_season_capability(uuid, uuid, text) from public, anon, authenticated;
