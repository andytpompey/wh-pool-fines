create or replace function public.current_team_cycle_entitlement(target_team_id uuid,target_playing_cycle_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object(
  'id',e.id,'state',case when e.revoked_at is not null then 'revoked' when now()<=e.valid_until then e.state::text when e.grace_until is not null and now()<=e.grace_until then 'grace' else 'expired' end,
  'subscriptionState',s.state,'validFrom',e.valid_from,'validUntil',e.valid_until,'graceUntil',e.grace_until,'source',e.source,'capabilities',d.capabilities,
  'purchaser',case when public.can_manage_team_operations(target_team_id) then coalesce(b.billing_name,b.billing_email,case when e.source in ('trial','complimentary','correction') then 'RooBin administrator' end) end
 ) from public.team_season_entitlements e join public.entitlement_definitions d on d.id=e.entitlement_definition_id left join public.commercial_subscriptions s on s.id=e.subscription_id left join public.billing_customers b on b.id=s.billing_customer_id
 where e.team_id=target_team_id and e.playing_cycle_id=target_playing_cycle_id and (public.is_member_of_team(target_team_id) or public.is_platform_admin()) order by (e.revoked_at is null) desc,e.valid_until desc limit 1),jsonb_build_object('state','missing','activationState','awaiting_team_purchase_or_league_activation','capabilities','{}'::jsonb));
$$;
