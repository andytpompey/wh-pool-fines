create or replace function public.begin_app_store_team_purchase(target_team_id uuid, target_playing_cycle_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected_offering public.commercial_offerings; selected_price public.commercial_price_versions; selected_cycle public.team_playing_cycles; context_id uuid;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then raise exception 'Team leadership access required'; end if;
  select * into selected_cycle from public.team_playing_cycles c where c.id = target_playing_cycle_id and c.team_id = target_team_id;
  if selected_cycle.id is null then raise exception 'Playing cycle not found'; end if;
  if selected_cycle.starts_on is null or selected_cycle.ends_on is null then raise exception 'Set the playing-cycle dates before purchase'; end if;
  if selected_cycle.status in ('abandoned','cancelled') then raise exception 'This playing cycle cannot be purchased'; end if;
  if exists (select 1 from public.team_season_entitlements e where e.team_id=target_team_id and e.playing_cycle_id=target_playing_cycle_id and e.revoked_at is null and e.state in ('trial','active','grace','complimentary') and now() <= coalesce(e.grace_until,e.valid_until)) then raise exception 'This team playing cycle already has access'; end if;
  select * into selected_offering from public.commercial_offerings o where o.code='team-season-standard' and o.state='published' and 'ios'=any(o.sales_channels) order by o.version desc limit 1;
  select * into selected_price from public.commercial_price_versions p where p.offering_id=selected_offering.id and p.state='published' and p.effective_from<=now() and (p.effective_to is null or p.effective_to>now()) order by p.effective_from desc limit 1;
  if selected_price.id is null or selected_price.provider_price_refs->>'app_store' is null then raise exception 'App Store purchase is awaiting activation'; end if;
  insert into public.app_store_purchase_contexts (owner_user_id,team_id,playing_cycle_id,offering_id,price_version_id,product_id)
  values (auth.uid(),target_team_id,target_playing_cycle_id,selected_offering.id,selected_price.id,selected_price.provider_price_refs->>'app_store') returning id into context_id;
  return jsonb_build_object('contextId',context_id,'playingCycleId',selected_cycle.id,'productId',selected_price.provider_price_refs->>'app_store','amountMinor',selected_price.amount_minor,'currency',selected_price.currency,'cycleName',selected_cycle.name,'startsOn',selected_cycle.starts_on,'endsOn',selected_cycle.ends_on);
end $$;

revoke all on function public.begin_app_store_team_purchase(uuid,uuid) from public, anon;
grant execute on function public.begin_app_store_team_purchase(uuid,uuid) to authenticated;
