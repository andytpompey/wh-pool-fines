alter table public.billing_customers add column billing_address jsonb not null default '{}'::jsonb;
alter table public.billing_customers drop constraint billing_customers_customer_type_check;
alter table public.billing_customers add constraint billing_customers_customer_type_check check(customer_type in ('individual','team','league','club','venue','organisation'));

create or replace function public.require_recent_commercial_authentication()
returns void language plpgsql stable security definer set search_path='' as $$
declare token_iat bigint;
begin
 token_iat:=coalesce((auth.jwt()->>'iat')::bigint,0);
 if auth.uid() is null or extract(epoch from now())-token_iat>600 then raise exception 'Recent identity verification is required'; end if;
end $$;

create or replace function public.update_billing_customer_profile(target_billing_customer_id uuid,new_name text,new_email text,new_address jsonb,new_tax_identifier text,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare customer public.billing_customers; before_row jsonb; changed public.billing_customers;
begin
 perform public.require_recent_commercial_authentication();
 select * into customer from public.billing_customers where id=target_billing_customer_id for update;
 if customer.owner_user_id<>auth.uid() and not public.is_platform_admin() then raise exception 'Billing owner access required'; end if;
 if length(btrim(new_name))<2 or new_email!~*'^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' or coalesce(new_address->>'countryCode','')!~'^[A-Z]{2}$' or length(btrim(reason))<8 then raise exception 'Complete billing profile and reason are required'; end if;
 before_row:=to_jsonb(customer)-'provider_customer_refs';
 update public.billing_customers set billing_name=btrim(new_name),billing_email=lower(btrim(new_email)),billing_address=jsonb_strip_nulls(new_address),country_code=new_address->>'countryCode',tax_identifier=nullif(btrim(new_tax_identifier),''),updated_at=now() where id=customer.id returning * into changed;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'billing_profile.updated','billing_customer',changed.id::text,before_row,to_jsonb(changed)-'provider_customer_refs',btrim(reason));
 return jsonb_build_object('success',true,'billingCustomerId',changed.id);
end $$;

create or replace function public.manage_billing_customer_contact(target_billing_customer_id uuid,contact_email text,new_role text,contact_action text,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare customer public.billing_customers; contact_user uuid; contact public.billing_customer_contacts;
begin
 perform public.require_recent_commercial_authentication();
 select * into customer from public.billing_customers where id=target_billing_customer_id for update;
 if customer.owner_user_id<>auth.uid() and not public.is_platform_admin() then raise exception 'Billing owner access required'; end if;
 if new_role not in ('administrator','viewer') or contact_action not in ('grant','remove') or length(btrim(reason))<8 then raise exception 'Valid contact action and reason are required'; end if;
 select id into contact_user from auth.users where lower(email)=lower(btrim(contact_email)) and email_confirmed_at is not null;
 if contact_user is null or contact_user=customer.owner_user_id then raise exception 'Verified non-owner contact account is required'; end if;
 insert into public.billing_customer_contacts(billing_customer_id,user_id,role,status,verified_at) values(customer.id,contact_user,new_role,case when contact_action='grant' then 'active' else 'removed' end,case when contact_action='grant' then now() end)
 on conflict(billing_customer_id,user_id) do update set role=excluded.role,status=excluded.status,verified_at=excluded.verified_at,updated_at=now() returning * into contact;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'billing_contact.'||contact_action,'billing_customer',customer.id::text,jsonb_build_object('contactUserId',contact.user_id,'role',contact.role,'status',contact.status),btrim(reason));
 return jsonb_build_object('success',true,'userId',contact.user_id,'status',contact.status);
end $$;

create or replace function public.my_team_billing_context(target_team_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('id',b.id,'billingName',b.billing_name,'billingEmail',case when exists(select 1 from public.billing_customer_contacts c where c.billing_customer_id=b.id and c.user_id=auth.uid() and c.status='active') or public.is_platform_admin() then b.billing_email end,'billingAddress',case when b.owner_user_id=auth.uid() or public.is_platform_admin() then b.billing_address end,'taxIdentifier',case when b.owner_user_id=auth.uid() or public.is_platform_admin() then b.tax_identifier end,'isOwner',b.owner_user_id=auth.uid(),'providerReady',b.provider_customer_refs?'stripe','contacts',case when b.owner_user_id=auth.uid() or public.is_platform_admin() then (select coalesce(jsonb_agg(jsonb_build_object('userId',c.user_id,'role',c.role,'status',c.status)),'[]'::jsonb) from public.billing_customer_contacts c where c.billing_customer_id=b.id) else '[]'::jsonb end) from public.billing_customers b where b.team_id=target_team_id and (b.owner_user_id=auth.uid() or public.is_member_of_team(target_team_id) or public.is_platform_admin()) order by b.updated_at desc limit 1),jsonb_build_object('state','missing'));
$$;

revoke all on function public.require_recent_commercial_authentication() from public,anon,authenticated;
revoke all on function public.update_billing_customer_profile(uuid,text,text,jsonb,text,text) from public,anon;
revoke all on function public.manage_billing_customer_contact(uuid,text,text,text,text) from public,anon;
grant execute on function public.update_billing_customer_profile(uuid,text,text,jsonb,text,text) to authenticated;
grant execute on function public.manage_billing_customer_contact(uuid,text,text,text,text) to authenticated;
