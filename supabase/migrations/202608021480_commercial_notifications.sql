create table public.commercial_notification_deliveries (
 id uuid primary key default gen_random_uuid(),
 notification_key text not null unique,
 notification_type text not null check(notification_type in ('renewal_reminder','expiry_reminder','payment_failed','payment_recovered','cancelled','refunded','dispute')),
 billing_customer_id uuid references public.billing_customers(id),
 subscription_id uuid references public.commercial_subscriptions(id),
 entitlement_id uuid references public.team_season_entitlements(id),
 recipient_digest text not null,
 provider text not null default 'resend',
 provider_message_id text,
 status text not null check(status in ('queued','delivered','failed','suppressed')),
 attempt_count integer not null default 0,
 last_error_code text,
 scheduled_for timestamptz not null,
 delivered_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.commercial_notification_deliveries enable row level security;
revoke all on public.commercial_notification_deliveries from anon,authenticated;

create or replace view public.commercial_notifications_due
with (security_invoker=false) as
select concat('expiry:',e.id,':',threshold.days_before) notification_key,
 'expiry_reminder'::text notification_type,e.id entitlement_id,e.subscription_id,s.billing_customer_id,
 coalesce(b.billing_email,(select p2.email from public.team_memberships tm2 join public.players p2 on p2.id=tm2.player_id where tm2.team_id=e.team_id and tm2.status='active' and tm2.role='captain' and p2.email is not null order by tm2.joined_at limit 1)) recipient,t.name team_name,c.name cycle_name,e.valid_until,
 p.amount_minor,p.currency,o.renewal_behaviour,threshold.days_before
from public.team_season_entitlements e
join public.team_playing_cycles c on c.id=e.playing_cycle_id
join public.teams t on t.id=e.team_id
left join public.commercial_subscriptions s on s.id=e.subscription_id
left join public.billing_customers b on b.id=s.billing_customer_id
left join public.commercial_price_versions p on p.id=s.price_version_id
left join public.commercial_offerings o on o.id=s.offering_id
cross join lateral (select jsonb_array_elements_text(coalesce((select value->'daysBefore' from public.commercial_settings where key='renewal_reminders'),'[30,14,3]'::jsonb))::integer days_before) threshold
where e.revoked_at is null and e.state in ('trial','active','grace','complimentary')
 and coalesce(b.billing_email,(select p2.email from public.team_memberships tm2 join public.players p2 on p2.id=tm2.player_id where tm2.team_id=e.team_id and tm2.status='active' and tm2.role='captain' and p2.email is not null order by tm2.joined_at limit 1)) is not null
 and e.valid_until::date-current_date=threshold.days_before
 and not exists(select 1 from public.commercial_notification_deliveries d where d.notification_key=concat('expiry:',e.id,':',threshold.days_before));
revoke all on public.commercial_notifications_due from anon,authenticated;

create or replace function public.commercial_notification_summary()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then jsonb_build_object(
  'due',(select count(*) from public.commercial_notifications_due),
  'failed',(select count(*) from public.commercial_notification_deliveries where status='failed'),
  'delivered30Days',(select count(*) from public.commercial_notification_deliveries where status='delivered' and delivered_at>=now()-interval '30 days')
 ) else null end;
$$;
revoke all on function public.commercial_notification_summary() from public,anon;
grant execute on function public.commercial_notification_summary() to authenticated;
