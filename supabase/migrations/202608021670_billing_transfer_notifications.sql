alter table public.commercial_notification_deliveries add column recipient_address text;
alter table public.commercial_notification_deliveries drop constraint commercial_notification_deliveries_notification_type_check;
alter table public.commercial_notification_deliveries add constraint commercial_notification_deliveries_notification_type_check check(notification_type in ('renewal_reminder','expiry_reminder','payment_failed','payment_recovered','cancelled','refunded','dispute','billing_transfer_requested','billing_transfer_completed','billing_recovery_completed'));

create or replace view public.commercial_lifecycle_notifications_due with(security_invoker=false) as
select d.id,d.notification_key,d.notification_type,d.subscription_id,d.entitlement_id,coalesce(d.recipient_address,b.billing_email) recipient,t.name team_name,c.name cycle_name,s.current_period_end
from public.commercial_notification_deliveries d left join public.billing_customers b on b.id=d.billing_customer_id left join public.commercial_subscriptions s on s.id=d.subscription_id left join public.teams t on t.id=coalesce(s.team_id,b.team_id) left join public.team_playing_cycles c on c.id=s.playing_cycle_id
where d.status in ('queued','failed') and d.attempt_count<5 and d.scheduled_for<=now() and coalesce(d.recipient_address,b.billing_email) is not null;
revoke all on public.commercial_lifecycle_notifications_due from anon,authenticated;

create or replace function public.queue_billing_transfer_notifications() returns trigger language plpgsql security definer set search_path='' as $$
declare from_email text; to_email text;
begin
 select email into from_email from auth.users where id=new.from_user_id; select email into to_email from auth.users where id=new.to_user_id;
 if tg_op='INSERT' and new.state='pending' then
  insert into public.commercial_notification_deliveries(notification_key,notification_type,billing_customer_id,recipient_address,recipient_digest,status,scheduled_for) values('billing-transfer-requested:'||new.id||':from','billing_transfer_requested',new.billing_customer_id,from_email,encode(extensions.digest(lower(from_email),'sha256'),'hex'),'queued',now()),('billing-transfer-requested:'||new.id||':to','billing_transfer_requested',new.billing_customer_id,to_email,encode(extensions.digest(lower(to_email),'sha256'),'hex'),'queued',now()) on conflict(notification_key) do nothing;
 elsif tg_op='UPDATE' and old.state='pending' and new.state='accepted' then
  insert into public.commercial_notification_deliveries(notification_key,notification_type,billing_customer_id,recipient_address,recipient_digest,status,scheduled_for) values('billing-transfer-completed:'||new.id||':from','billing_transfer_completed',new.billing_customer_id,from_email,encode(extensions.digest(lower(from_email),'sha256'),'hex'),'queued',now()),('billing-transfer-completed:'||new.id||':to','billing_transfer_completed',new.billing_customer_id,to_email,encode(extensions.digest(lower(to_email),'sha256'),'hex'),'queued',now()) on conflict(notification_key) do nothing;
 end if; return new;
end $$;
create trigger billing_transfer_notification_queue after insert or update on public.billing_contact_transfers for each row execute function public.queue_billing_transfer_notifications();

create or replace function public.queue_billing_recovery_notifications() returns trigger language plpgsql security definer set search_path='' as $$
declare old_email text; new_email text;
begin
 if old.state='pending' and new.state='approved' then
  select u.email into old_email from public.billing_customers b join auth.users u on u.id=(select c.user_id from public.billing_customer_contacts c where c.billing_customer_id=b.id and c.role='administrator' and c.status='active' order by c.updated_at desc limit 1) where b.id=new.billing_customer_id;
  select email into new_email from auth.users where id=new.replacement_user_id;
  if old_email is not null then insert into public.commercial_notification_deliveries(notification_key,notification_type,billing_customer_id,recipient_address,recipient_digest,status,scheduled_for) values('billing-recovery-completed:'||new.id||':old','billing_recovery_completed',new.billing_customer_id,old_email,encode(extensions.digest(lower(old_email),'sha256'),'hex'),'queued',now()) on conflict(notification_key) do nothing; end if;
  insert into public.commercial_notification_deliveries(notification_key,notification_type,billing_customer_id,recipient_address,recipient_digest,status,scheduled_for) values('billing-recovery-completed:'||new.id||':new','billing_recovery_completed',new.billing_customer_id,new_email,encode(extensions.digest(lower(new_email),'sha256'),'hex'),'queued',now()) on conflict(notification_key) do nothing;
 end if; return new;
end $$;
create trigger billing_recovery_notification_queue after update on public.billing_recovery_requests for each row execute function public.queue_billing_recovery_notifications();
