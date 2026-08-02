create or replace view public.commercial_lifecycle_notifications_due
with (security_invoker=false) as
select d.id,d.notification_key,d.notification_type,d.subscription_id,d.entitlement_id,b.billing_email recipient,t.name team_name,c.name cycle_name,s.current_period_end
from public.commercial_notification_deliveries d
join public.billing_customers b on b.id=d.billing_customer_id
left join public.commercial_subscriptions s on s.id=d.subscription_id
left join public.teams t on t.id=s.team_id
left join public.team_playing_cycles c on c.id=s.playing_cycle_id
where d.status in ('queued','failed') and d.attempt_count<5 and d.scheduled_for<=now() and b.billing_email is not null;
revoke all on public.commercial_lifecycle_notifications_due from anon,authenticated;
