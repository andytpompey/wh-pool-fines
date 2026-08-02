-- Server-owned commercial enforcement. Observe mode is the safe migration
-- default; switching to enforce is blocked while active cycles lack access.

create or replace function public.commercial_enforcement_mode()
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((value ->> 'mode'), 'observe') from public.commercial_settings where key = 'entitlement_enforcement';
$$;

create or replace function public.commercial_match_write_allowed(target_team_id uuid, target_season_id uuid, capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when public.commercial_enforcement_mode() <> 'enforce' then true
    when target_season_id is null then false
    else public.has_team_season_capability(target_team_id, target_season_id, capability)
  end;
$$;

create or replace function public.commercial_team_write_allowed(target_team_id uuid, capability text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when public.commercial_enforcement_mode() <> 'enforce' then true
    else exists (
      select 1 from public.team_season_entitlements e
      join public.entitlement_definitions d on d.id = e.entitlement_definition_id
      where e.team_id = target_team_id
        and (public.is_member_of_team(target_team_id) or public.is_platform_admin())
        and e.revoked_at is null and now() between e.valid_from and coalesce(e.grace_until, e.valid_until)
        and e.state in ('trial', 'active', 'grace', 'complimentary')
        and coalesce((d.capabilities ->> capability)::boolean, false)
    )
  end;
$$;

create or replace function public.guard_commercial_operational_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_team_id uuid; target_season_id uuid;
begin
  if tg_table_name = 'matches' then
    target_team_id := new.team_id;
    target_season_id := new.season_id;
  elsif tg_table_name in ('fines', 'subs', 'match_players') then
    select m.team_id, m.season_id into target_team_id, target_season_id from public.matches m where m.id = new.match_id;
  else
    raise exception 'Unsupported commercial guard target';
  end if;
  if target_team_id is null or not public.commercial_match_write_allowed(target_team_id, target_season_id, 'matches') then
    raise exception 'Commercial entitlement required [COMMERCIAL_ENTITLEMENT_REQUIRED]';
  end if;
  return new;
end $$;

create trigger matches_commercial_guard before insert or update on public.matches
for each row execute function public.guard_commercial_operational_write();
create trigger fines_commercial_guard before insert or update on public.fines
for each row execute function public.guard_commercial_operational_write();
create trigger subs_commercial_guard before insert or update on public.subs
for each row execute function public.guard_commercial_operational_write();
create trigger match_players_commercial_guard before insert or update on public.match_players
for each row execute function public.guard_commercial_operational_write();

drop policy if exists "team scoped insert" on public.fine_types;
drop policy if exists "team scoped update" on public.fine_types;
create policy "team scoped insert" on public.fine_types for insert to authenticated
with check (public.can_manage_team_operations(team_id) and public.commercial_team_write_allowed(team_id, 'team_management'));
create policy "team scoped update" on public.fine_types for update to authenticated
using (public.can_manage_team_operations(team_id) and public.commercial_team_write_allowed(team_id, 'team_management'))
with check (public.can_manage_team_operations(team_id) and public.commercial_team_write_allowed(team_id, 'team_management'));

create or replace view public.commercial_enforcement_gaps
with (security_invoker = false) as
select c.id as playing_cycle_id, c.team_id, c.name, c.status, c.starts_on, c.ends_on
from public.team_playing_cycles c
where c.status in ('active', 'planned')
  and not exists (
    select 1 from public.team_season_entitlements e
    where e.playing_cycle_id = c.id and e.team_id = c.team_id and e.revoked_at is null
      and e.state in ('trial', 'active', 'grace', 'complimentary')
      and now() <= coalesce(e.grace_until, e.valid_until)
  );
revoke all on public.commercial_enforcement_gaps from anon, authenticated;

create or replace function public.set_commercial_enforcement(next_mode text, reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare gap_count integer; previous jsonb; next_value jsonb;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if next_mode not in ('observe', 'enforce') then raise exception 'Unsupported enforcement mode'; end if;
  if reason is null or length(btrim(reason)) < 12 then raise exception 'A detailed rollout reason is required'; end if;
  if next_mode = 'enforce' then
    select count(*) into gap_count from public.commercial_enforcement_gaps;
    if gap_count > 0 then raise exception 'Cannot enforce while % active or planned playing cycles lack entitlement', gap_count; end if;
  end if;
  select value into previous from public.commercial_settings where key = 'entitlement_enforcement' for update;
  next_value := coalesce(previous, '{}'::jsonb) || jsonb_build_object('mode', next_mode, 'changedAt', now(), 'changedBy', auth.uid());
  insert into public.commercial_settings (key, value, updated_by, updated_at)
  values ('entitlement_enforcement', next_value, auth.uid(), now())
  on conflict (key) do update set value = excluded.value, updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (auth.uid(), 'enforcement.changed', 'commercial_setting', 'entitlement_enforcement', previous, next_value, btrim(reason));
  return next_value;
end $$;

revoke all on function public.commercial_enforcement_mode() from public, anon, authenticated;
revoke all on function public.commercial_match_write_allowed(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.commercial_team_write_allowed(uuid, text) from public, anon, authenticated;
revoke all on function public.guard_commercial_operational_write() from public, anon, authenticated;
revoke all on function public.set_commercial_enforcement(text, text) from public, anon;
grant execute on function public.set_commercial_enforcement(text, text) to authenticated;
grant execute on function public.commercial_team_write_allowed(uuid, text) to authenticated;

comment on view public.commercial_enforcement_gaps is 'Platform-only go-live gate: cycles that would lose paid writes if enforcement were enabled.';
