create table public.billing_customer_contacts (
 id uuid primary key default gen_random_uuid(),billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
 user_id uuid not null references auth.users(id),role text not null check(role in ('owner','administrator','viewer')),
 status text not null default 'active' check(status in ('invited','active','removed')),verified_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(billing_customer_id,user_id)
);
insert into public.billing_customer_contacts(billing_customer_id,user_id,role,status,verified_at) select id,owner_user_id,'owner','active',created_at from public.billing_customers on conflict do nothing;

create table public.billing_contact_transfers (
 id uuid primary key default gen_random_uuid(),billing_customer_id uuid not null references public.billing_customers(id),from_user_id uuid not null references auth.users(id),to_user_id uuid not null references auth.users(id),
 state text not null default 'pending' check(state in ('pending','accepted','rejected','expired','cancelled','admin_approved')),reason text not null,expires_at timestamptz not null default now()+interval '7 days',created_at timestamptz not null default now(),completed_at timestamptz
);
create unique index one_pending_billing_transfer on public.billing_contact_transfers(billing_customer_id) where state='pending';
alter table public.billing_customer_contacts enable row level security; alter table public.billing_contact_transfers enable row level security;
revoke all on public.billing_customer_contacts,public.billing_contact_transfers from anon,authenticated;
grant select on public.billing_customer_contacts to authenticated;
create policy "billing contacts view own customer" on public.billing_customer_contacts for select to authenticated using(user_id=auth.uid() or public.is_platform_admin());

create or replace function public.create_commercial_offering_draft(configuration jsonb,reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare created public.commercial_offerings; channels public.commercial_channel[];
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if length(btrim(reason))<8 or coalesce(configuration->>'code','')!~'^[a-z0-9][a-z0-9-]{2,63}$' then raise exception 'Valid code and reason are required'; end if;
 select array_agg(value::public.commercial_channel) into channels from jsonb_array_elements_text(configuration->'salesChannels');
 if cardinality(channels)=0 then raise exception 'At least one sales channel is required'; end if;
 insert into public.commercial_offerings(product_id,code,version,customer_type,billing_unit,billing_interval,currency,tax_behaviour,entitlement_definition_id,min_quantity,max_quantity,trial_days,renewal_behaviour,sales_channels,eligibility,state,created_by)
 values((configuration->>'productId')::uuid,configuration->>'code',coalesce((configuration->>'version')::integer,1),configuration->>'customerType',configuration->>'billingUnit',configuration->>'billingInterval',upper(configuration->>'currency'),configuration->>'taxBehaviour',(configuration->>'entitlementDefinitionId')::uuid,coalesce((configuration->>'minQuantity')::integer,1),nullif(configuration->>'maxQuantity','')::integer,coalesce((configuration->>'trialDays')::integer,0),configuration->>'renewalBehaviour',channels,coalesce(configuration->'eligibility','{}'),'draft',auth.uid()) returning * into created;
 if created.renewal_behaviour='automatic' and created.billing_interval in ('one_time','season') then raise exception 'Automatic renewal requires a fixed interval'; end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'offering.draft_created','commercial_offering',created.id::text,to_jsonb(created),btrim(reason));
 return created;
exception when invalid_text_representation or not_null_violation or check_violation or foreign_key_violation then raise exception 'Offering configuration is incomplete or unsupported';
end $$;

create or replace function public.initiate_billing_contact_transfer(target_billing_customer_id uuid,replacement_user_id uuid,transfer_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare customer public.billing_customers; created public.billing_contact_transfers; token_iat bigint;
begin
 select * into customer from public.billing_customers where id=target_billing_customer_id for update;
 if customer.owner_user_id<>auth.uid() then raise exception 'Current billing owner access required'; end if;
 token_iat:=coalesce((auth.jwt()->>'iat')::bigint,0); if extract(epoch from now())-token_iat>600 then raise exception 'Recent identity verification is required'; end if;
 if replacement_user_id=auth.uid() or not exists(select 1 from public.app_users where id=replacement_user_id) then raise exception 'Verified replacement account is required'; end if;
 insert into public.billing_contact_transfers(billing_customer_id,from_user_id,to_user_id,reason) values(customer.id,auth.uid(),replacement_user_id,btrim(transfer_reason)) returning * into created;
 insert into public.billing_customer_contacts(billing_customer_id,user_id,role,status) values(customer.id,replacement_user_id,'owner','invited') on conflict(billing_customer_id,user_id) do update set role='owner',status='invited',updated_at=now();
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'billing_transfer.initiated','billing_customer',customer.id::text,jsonb_build_object('transferId',created.id,'replacementUserId',replacement_user_id),btrim(transfer_reason));
 return jsonb_build_object('transferId',created.id,'state',created.state,'expiresAt',created.expires_at);
end $$;

create or replace function public.accept_billing_contact_transfer(target_transfer_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare transfer public.billing_contact_transfers; customer public.billing_customers;
begin
 select * into transfer from public.billing_contact_transfers where id=target_transfer_id for update;
 if transfer.to_user_id<>auth.uid() or transfer.state<>'pending' or transfer.expires_at<=now() then raise exception 'Pending transfer is unavailable'; end if;
 select * into customer from public.billing_customers where id=transfer.billing_customer_id for update;
 if exists(select 1 from public.billing_customers where owner_user_id=auth.uid() and team_id is not distinct from customer.team_id and id<>customer.id) then raise exception 'Replacement already owns a billing customer for this team'; end if;
 update public.billing_customers set owner_user_id=auth.uid(),updated_at=now() where id=customer.id;
 update public.billing_customer_contacts set role='administrator',updated_at=now() where billing_customer_id=customer.id and user_id=transfer.from_user_id;
 update public.billing_customer_contacts set role='owner',status='active',verified_at=now(),updated_at=now() where billing_customer_id=customer.id and user_id=auth.uid();
 update public.billing_contact_transfers set state='accepted',completed_at=now() where id=transfer.id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'billing_transfer.accepted','billing_customer',customer.id::text,jsonb_build_object('ownerUserId',transfer.from_user_id),jsonb_build_object('ownerUserId',auth.uid()),transfer.reason);
 return jsonb_build_object('success',true,'billingCustomerId',customer.id);
end $$;

create or replace function public.get_commercial_accounting_export(period_start timestamptz,period_end timestamptz)
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() and period_end>period_start then coalesce((select jsonb_agg(jsonb_build_object('occurredAt',f.occurred_at,'provider',f.provider,'providerReference',f.provider_reference,'entryType',f.entry_type,'currency',f.currency,'grossAmountMinor',f.gross_amount_minor,'discountAmountMinor',f.discount_amount_minor,'taxAmountMinor',f.tax_amount_minor,'processorFeeMinor',f.processor_fee_minor,'netAmountMinor',f.net_amount_minor,'receiptUrl',f.receipt_url,'subscriptionId',f.subscription_id) order by f.occurred_at) from public.commercial_financial_entries f where f.occurred_at>=period_start and f.occurred_at<period_end),'[]'::jsonb) else null end;
$$;

create or replace function public.set_service_component(target_code text,new_status text,public_message text,reason text)
returns public.service_components language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.service_components;
begin
 if not public.is_platform_admin() then raise exception 'Incident administrator access required'; end if;
 if new_status not in ('operational','degraded','partial_outage','major_outage','maintenance') or length(btrim(reason))<8 then raise exception 'Valid status and reason are required'; end if;
 select to_jsonb(c) into before_row from public.service_components c where code=target_code for update;
 update public.service_components set status=new_status,message=nullif(btrim(public_message),''),updated_at=now() where code=target_code returning * into changed;
 if changed.code is null then raise exception 'Service component not found'; end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'service_component.updated','service_component',changed.code,before_row,to_jsonb(changed),btrim(reason)); return changed;
end $$;

create or replace function public.create_service_incident(title text,impact text,public_message text,component_codes text[],reason text)
returns public.service_incidents language plpgsql security definer set search_path='' as $$
declare created public.service_incidents;
begin
 if not public.is_platform_admin() then raise exception 'Incident administrator access required'; end if;
 if impact not in ('none','minor','major','critical') or length(btrim(title))<5 or length(btrim(public_message))<10 or length(btrim(reason))<8 then raise exception 'Incident details and reason are required'; end if;
 insert into public.service_incidents(title,status,impact,public_message,started_at,created_by) values(btrim(title),'investigating',impact,btrim(public_message),now(),auth.uid()) returning * into created;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'incident.created','service_incident',created.id::text,to_jsonb(created)||jsonb_build_object('components',component_codes),btrim(reason)); return created;
end $$;

revoke all on function public.create_commercial_offering_draft(jsonb,text) from public,anon;
revoke all on function public.initiate_billing_contact_transfer(uuid,uuid,text) from public,anon;
revoke all on function public.accept_billing_contact_transfer(uuid) from public,anon;
revoke all on function public.get_commercial_accounting_export(timestamptz,timestamptz) from public,anon;
revoke all on function public.set_service_component(text,text,text,text) from public,anon;
revoke all on function public.create_service_incident(text,text,text,text[],text) from public,anon;
grant execute on function public.create_commercial_offering_draft(jsonb,text) to authenticated;
grant execute on function public.initiate_billing_contact_transfer(uuid,uuid,text) to authenticated;
grant execute on function public.accept_billing_contact_transfer(uuid) to authenticated;
grant execute on function public.get_commercial_accounting_export(timestamptz,timestamptz) to authenticated;
grant execute on function public.set_service_component(text,text,text,text) to authenticated;
grant execute on function public.create_service_incident(text,text,text,text[],text) to authenticated;
