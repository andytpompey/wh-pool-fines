alter table public.commercial_offerings add column refund_policy jsonb not null default '{"cancellationTiming":"end_of_term","partialRefundAccess":"operator_review","coolingOffDays":14,"immediateCancellationRequiresRefund":true}'::jsonb;
alter table public.commercial_offerings add constraint commercial_offering_refund_policy_valid check(
 refund_policy->>'cancellationTiming' in ('end_of_term','immediate') and refund_policy->>'partialRefundAccess' in ('retain_until_end','end_immediately','operator_review')
 and (refund_policy->>'coolingOffDays')::integer between 0 and 30 and jsonb_typeof(refund_policy->'immediateCancellationRequiresRefund')='boolean');

create or replace function public.update_draft_commercial_refund_policy(target_offering_id uuid,new_policy jsonb,reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.commercial_offerings;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if length(btrim(reason))<8 or new_policy->>'cancellationTiming' not in ('end_of_term','immediate') or new_policy->>'partialRefundAccess' not in ('retain_until_end','end_immediately','operator_review') or (new_policy->>'coolingOffDays')::integer not between 0 and 30 or jsonb_typeof(new_policy->'immediateCancellationRequiresRefund')<>'boolean' then raise exception 'Valid refund policy and reason are required'; end if;
 select to_jsonb(o) into before_row from public.commercial_offerings o where id=target_offering_id and state='draft' for update;
 if before_row is null then raise exception 'Draft offering not found'; end if;
 update public.commercial_offerings set refund_policy=new_policy where id=target_offering_id returning * into changed;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'offering.refund_policy_updated','commercial_offering',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 return changed;
end $$;
revoke all on function public.update_draft_commercial_refund_policy(uuid,jsonb,text) from public,anon;
grant execute on function public.update_draft_commercial_refund_policy(uuid,jsonb,text) to authenticated;

create or replace function public.current_team_cycle_entitlement(target_team_id uuid,target_playing_cycle_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object(
  'id',e.id,'state',case when e.revoked_at is not null then 'revoked' when now()<=e.valid_until then e.state::text when e.grace_until is not null and now()<=e.grace_until then 'grace' else 'expired' end,
  'subscriptionState',s.state,'cancelAtPeriodEnd',s.cancel_at_period_end,'currentPeriodEnd',s.current_period_end,'refundPolicy',o.refund_policy,
  'validFrom',e.valid_from,'validUntil',e.valid_until,'graceUntil',e.grace_until,'source',e.source,'capabilities',d.capabilities,
  'purchaser',case when public.can_manage_team_operations(target_team_id) then coalesce(b.billing_name,b.billing_email,case when e.source in ('trial','complimentary','correction') then 'RooBin administrator' end) end
 ) from public.team_season_entitlements e join public.entitlement_definitions d on d.id=e.entitlement_definition_id left join public.commercial_subscriptions s on s.id=e.subscription_id left join public.commercial_offerings o on o.id=s.offering_id left join public.billing_customers b on b.id=s.billing_customer_id
 where e.team_id=target_team_id and e.playing_cycle_id=target_playing_cycle_id and (public.is_member_of_team(target_team_id) or public.is_platform_admin()) order by (e.revoked_at is null) desc,e.valid_until desc limit 1),jsonb_build_object('state','missing','activationState','awaiting_team_purchase_or_league_activation','capabilities','{}'::jsonb));
$$;
