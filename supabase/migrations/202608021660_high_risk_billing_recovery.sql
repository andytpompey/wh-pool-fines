create table public.billing_recovery_requests(
 id uuid primary key default gen_random_uuid(),billing_customer_id uuid not null references public.billing_customers(id),replacement_user_id uuid not null references auth.users(id),
 state text not null default 'pending' check(state in ('pending','approved','rejected','cancelled','expired')),evidence_reference text not null,reason text not null,
 requested_by uuid not null references auth.users(id),approved_by uuid references auth.users(id),created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',completed_at timestamptz
);
create unique index one_pending_billing_recovery on public.billing_recovery_requests(billing_customer_id) where state='pending';
alter table public.billing_recovery_requests enable row level security;
revoke all on public.billing_recovery_requests from anon,authenticated;

create or replace function public.create_billing_recovery_request(target_billing_customer_id uuid,replacement_email text,evidence_reference text,recovery_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare replacement uuid; created public.billing_recovery_requests; customer public.billing_customers;
begin
 perform public.require_recent_commercial_authentication();
 if not public.is_platform_admin() then raise exception 'Platform administrator access required'; end if;
 select * into customer from public.billing_customers where id=target_billing_customer_id;
 select id into replacement from auth.users where lower(email)=lower(btrim(replacement_email)) and email_confirmed_at is not null;
 if customer.id is null or replacement is null or replacement=customer.owner_user_id or length(btrim(evidence_reference))<8 or length(btrim(recovery_reason))<12 then raise exception 'Verified recovery target, evidence and detailed reason are required'; end if;
 insert into public.billing_recovery_requests(billing_customer_id,replacement_user_id,evidence_reference,reason,requested_by) values(customer.id,replacement,btrim(evidence_reference),btrim(recovery_reason),auth.uid()) returning * into created;
 insert into public.commercial_operator_cases(case_type,state,priority,subscription_id,provider_reference,summary,safe_details) values('billing_transfer','waiting_approval','urgent',null,created.id::text,'High-risk billing recovery awaiting independent approval',jsonb_build_object('billingCustomerId',customer.id,'replacementUserId',replacement,'evidenceReference',created.evidence_reference));
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'billing_recovery.requested','billing_customer',customer.id::text,jsonb_build_object('requestId',created.id,'replacementUserId',replacement,'evidenceReference',created.evidence_reference),btrim(recovery_reason));
 return jsonb_build_object('requestId',created.id,'state',created.state,'expiresAt',created.expires_at);
end $$;

create or replace function public.approve_billing_recovery_request(target_request_id uuid,approval_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare recovery public.billing_recovery_requests; customer public.billing_customers;
begin
 perform public.require_recent_commercial_authentication();
 if not public.is_platform_admin() then raise exception 'Platform administrator access required'; end if;
 select * into recovery from public.billing_recovery_requests where id=target_request_id for update;
 if recovery.id is null or recovery.state<>'pending' or recovery.expires_at<=now() then raise exception 'Pending recovery is unavailable'; end if;
 if recovery.requested_by=auth.uid() then raise exception 'A different platform administrator must approve recovery'; end if;
 if length(btrim(approval_reason))<12 then raise exception 'Detailed independent approval reason is required'; end if;
 select * into customer from public.billing_customers where id=recovery.billing_customer_id for update;
 update public.billing_customers set owner_user_id=recovery.replacement_user_id,updated_at=now() where id=customer.id;
 update public.billing_customer_contacts set role='administrator',updated_at=now() where billing_customer_id=customer.id and user_id=customer.owner_user_id;
 insert into public.billing_customer_contacts(billing_customer_id,user_id,role,status,verified_at) values(customer.id,recovery.replacement_user_id,'owner','active',now()) on conflict(billing_customer_id,user_id) do update set role='owner',status='active',verified_at=now(),updated_at=now();
 update public.billing_recovery_requests set state='approved',approved_by=auth.uid(),completed_at=now() where id=recovery.id;
 update public.commercial_operator_cases set state='resolved',resolved_at=now(),updated_at=now(),safe_details=safe_details||jsonb_build_object('approvedBy',auth.uid()) where case_type='billing_transfer' and provider_reference=recovery.id::text and state='waiting_approval';
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'billing_recovery.approved','billing_customer',customer.id::text,jsonb_build_object('ownerUserId',customer.owner_user_id),jsonb_build_object('ownerUserId',recovery.replacement_user_id,'requestId',recovery.id),btrim(approval_reason));
 return jsonb_build_object('success',true,'billingCustomerId',customer.id,'ownerUserId',recovery.replacement_user_id);
end $$;

create or replace function public.get_pending_billing_recoveries()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'billingCustomerId',r.billing_customer_id,'teamName',t.name,'replacementUserId',r.replacement_user_id,'evidenceReference',r.evidence_reference,'reason',r.reason,'requestedBy',r.requested_by,'expiresAt',r.expires_at) order by r.created_at) from public.billing_recovery_requests r join public.billing_customers b on b.id=r.billing_customer_id left join public.teams t on t.id=b.team_id where r.state='pending' and r.expires_at>now()),'[]'::jsonb) else null end;
$$;
revoke all on function public.create_billing_recovery_request(uuid,text,text,text) from public,anon;
revoke all on function public.approve_billing_recovery_request(uuid,text) from public,anon;
revoke all on function public.get_pending_billing_recoveries() from public,anon;
grant execute on function public.create_billing_recovery_request(uuid,text,text,text) to authenticated;
grant execute on function public.approve_billing_recovery_request(uuid,text) to authenticated;
grant execute on function public.get_pending_billing_recoveries() to authenticated;
