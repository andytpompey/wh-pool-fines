insert into public.service_components(code,name,status) values
 ('authentication','Authentication','operational'),
 ('data','Data and entitlements','operational'),
 ('notifications','Notifications','operational'),
 ('payments','Payments','operational')
on conflict(code) do nothing;

alter table public.service_incidents add column affected_components text[] not null default '{}';
alter table public.service_incidents add column mitigation text;
alter table public.service_incidents add column post_incident_actions text[] not null default '{}';

create table public.service_incident_updates (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.service_incidents(id) on delete cascade,
  status text not null check(status in ('investigating','identified','monitoring','resolved')),
  public_message text not null,
  mitigation text,
  created_by uuid not null references auth.users(id),
  published_at timestamptz not null default now()
);
alter table public.service_incident_updates enable row level security;
create policy "public incident updates" on public.service_incident_updates for select to anon,authenticated using(true);
grant select on public.service_incident_updates to anon,authenticated;

alter table public.commercial_notification_deliveries add column payload jsonb not null default '{}';
alter table public.commercial_notification_deliveries drop constraint commercial_notification_deliveries_notification_type_check;
alter table public.commercial_notification_deliveries add constraint commercial_notification_deliveries_notification_type_check check(notification_type in ('renewal_reminder','expiry_reminder','payment_failed','payment_recovered','cancelled','refunded','dispute','billing_transfer_requested','billing_transfer_completed','billing_recovery_completed','service_incident'));

create or replace view public.commercial_lifecycle_notifications_due with(security_invoker=false) as
select d.id,d.notification_key,d.notification_type,d.subscription_id,d.entitlement_id,coalesce(d.recipient_address,b.billing_email) recipient,t.name team_name,c.name cycle_name,s.current_period_end,d.payload
from public.commercial_notification_deliveries d left join public.billing_customers b on b.id=d.billing_customer_id left join public.commercial_subscriptions s on s.id=d.subscription_id left join public.teams t on t.id=coalesce(s.team_id,b.team_id) left join public.team_playing_cycles c on c.id=s.playing_cycle_id
where d.status in ('queued','failed') and d.attempt_count<5 and d.scheduled_for<=now() and coalesce(d.recipient_address,b.billing_email) is not null;
revoke all on public.commercial_lifecycle_notifications_due from anon,authenticated;

create or replace function public.queue_material_incident_notifications(target_incident_id uuid,target_update_id uuid,notification_payload jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare queued integer;
begin
 insert into public.commercial_notification_deliveries(notification_key,notification_type,billing_customer_id,recipient_digest,status,scheduled_for,payload)
 select 'service-incident:'||target_incident_id||':'||target_update_id||':'||b.id,'service_incident',b.id,
        encode(extensions.digest(lower(b.billing_email),'sha256'),'hex'),'queued',now(),jsonb_strip_nulls(notification_payload)
 from public.billing_customers b
 where b.billing_email is not null and exists(
   select 1 from public.commercial_subscriptions s where s.billing_customer_id=b.id and s.state in ('trialing','active','past_due','paused')
 ) on conflict(notification_key) do nothing;
 get diagnostics queued = row_count;
 return queued;
end $$;
revoke all on function public.queue_material_incident_notifications(uuid,uuid,jsonb) from public,anon,authenticated;

create or replace function public.create_service_incident(title text,impact text,public_message text,component_codes text[],reason text)
returns public.service_incidents language plpgsql security definer set search_path='' as $$
declare created public.service_incidents; update_id uuid; invalid_components text[];
begin
 if not public.is_platform_admin() then raise exception 'Incident administrator access required'; end if;
 select array_agg(requested.code) into invalid_components from unnest(component_codes) as requested(code) where not exists(select 1 from public.service_components c where c.code=requested.code);
 if impact not in ('none','minor','major','critical') or length(btrim(title))<5 or length(btrim(public_message))<10 or length(btrim(reason))<8 or cardinality(component_codes)<1 or invalid_components is not null then raise exception 'Incident details, valid components and reason are required'; end if;
 insert into public.service_incidents(title,status,impact,public_message,affected_components,started_at,created_by) values(btrim(title),'investigating',impact,btrim(public_message),component_codes,now(),auth.uid()) returning * into created;
 insert into public.service_incident_updates(incident_id,status,public_message,created_by) values(created.id,created.status,created.public_message,auth.uid()) returning id into update_id;
 if impact in ('major','critical') then perform public.queue_material_incident_notifications(created.id,update_id,jsonb_build_object('incidentId',created.id,'title',created.title,'impact',created.impact,'status',created.status,'message',created.public_message,'components',created.affected_components)); end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'incident.created','service_incident',created.id::text,to_jsonb(created),btrim(reason)); return created;
end $$;

create or replace function public.update_service_incident(target_incident_id uuid,new_status text,public_message text,mitigation text,post_incident_actions text[],notify_affected boolean,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare before_row public.service_incidents; changed public.service_incidents; update_id uuid; queued integer:=0;
begin
 if not public.is_platform_admin() then raise exception 'Incident administrator access required'; end if;
 if new_status not in ('investigating','identified','monitoring','resolved') or length(btrim(public_message))<10 or length(btrim(reason))<8 then raise exception 'Incident status, public update and reason are required'; end if;
 select * into before_row from public.service_incidents where id=target_incident_id for update;
 if before_row.id is null then raise exception 'Incident not found'; end if;
 if before_row.status='resolved' then raise exception 'Resolved incidents are immutable'; end if;
 if new_status='resolved' and (length(btrim(coalesce(mitigation,'')))<8 or cardinality(post_incident_actions)<1) then raise exception 'Resolution requires mitigation and tracked post-incident actions'; end if;
 update public.service_incidents set status=new_status,public_message=btrim($3),mitigation=nullif(btrim($4),''),post_incident_actions=coalesce($5,'{}'),resolved_at=case when new_status='resolved' then now() else null end,updated_at=now() where id=target_incident_id returning * into changed;
 insert into public.service_incident_updates(incident_id,status,public_message,mitigation,created_by) values(changed.id,new_status,changed.public_message,changed.mitigation,auth.uid()) returning id into update_id;
 if notify_affected and changed.impact in ('major','critical') then queued:=public.queue_material_incident_notifications(changed.id,update_id,jsonb_build_object('incidentId',changed.id,'title',changed.title,'impact',changed.impact,'status',changed.status,'message',changed.public_message,'mitigation',changed.mitigation,'components',changed.affected_components)); end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'incident.updated','service_incident',changed.id::text,to_jsonb(before_row),to_jsonb(changed)||jsonb_build_object('notificationsQueued',queued),btrim(reason));
 return jsonb_build_object('incidentId',changed.id,'status',changed.status,'updateId',update_id,'notificationsQueued',queued);
end $$;

create or replace function public.get_incident_admin_queue() returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then coalesce(jsonb_agg(to_jsonb(i) order by i.started_at desc),'[]'::jsonb) else null end from public.service_incidents i where i.status<>'resolved';
$$;
revoke all on function public.update_service_incident(uuid,text,text,text,text[],boolean,text) from public,anon;
revoke all on function public.get_incident_admin_queue() from public,anon;
grant execute on function public.update_service_incident(uuid,text,text,text,text[],boolean,text) to authenticated;
grant execute on function public.get_incident_admin_queue() to authenticated;
