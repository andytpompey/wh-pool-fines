create or replace function public.initiate_billing_contact_transfer_by_email(target_billing_customer_id uuid,replacement_email text,transfer_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare replacement_user_id uuid;
begin
 select id into replacement_user_id from auth.users where lower(email)=lower(btrim(replacement_email)) and email_confirmed_at is not null;
 if replacement_user_id is null then raise exception 'Verified replacement account is required'; end if;
 return public.initiate_billing_contact_transfer(target_billing_customer_id,replacement_user_id,transfer_reason);
end $$;

create or replace function public.my_team_billing_context(target_team_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('id',b.id,'billingName',b.billing_name,'billingEmail',case when exists(select 1 from public.billing_customer_contacts c where c.billing_customer_id=b.id and c.user_id=auth.uid() and c.status='active') or public.is_platform_admin() then b.billing_email end,'isOwner',b.owner_user_id=auth.uid(),'providerReady',b.provider_customer_refs?'stripe','contacts',case when b.owner_user_id=auth.uid() or public.is_platform_admin() then (select coalesce(jsonb_agg(jsonb_build_object('userId',c.user_id,'role',c.role,'status',c.status)),'[]'::jsonb) from public.billing_customer_contacts c where c.billing_customer_id=b.id) else '[]'::jsonb end) from public.billing_customers b where b.team_id=target_team_id and (b.owner_user_id=auth.uid() or public.is_member_of_team(target_team_id) or public.is_platform_admin()) order by b.updated_at desc limit 1),jsonb_build_object('state','missing'));
$$;

create or replace function public.my_pending_billing_transfers()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',tr.id,'billingCustomerId',tr.billing_customer_id,'teamId',b.team_id,'teamName',t.name,'fromUserId',tr.from_user_id,'expiresAt',tr.expires_at,'reason',tr.reason) order by tr.created_at),'[]'::jsonb)
 from public.billing_contact_transfers tr join public.billing_customers b on b.id=tr.billing_customer_id left join public.teams t on t.id=b.team_id
 where tr.to_user_id=auth.uid() and tr.state='pending' and tr.expires_at>now();
$$;
revoke all on function public.initiate_billing_contact_transfer_by_email(uuid,text,text) from public,anon;
revoke all on function public.my_team_billing_context(uuid) from public,anon;
revoke all on function public.my_pending_billing_transfers() from public,anon;
grant execute on function public.initiate_billing_contact_transfer_by_email(uuid,text,text) to authenticated;
grant execute on function public.my_team_billing_context(uuid) to authenticated;
grant execute on function public.my_pending_billing_transfers() to authenticated;
