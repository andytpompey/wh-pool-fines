create unique index commercial_discount_redemption_provider_reference on public.commercial_discount_redemptions(provider_reference) where provider_reference is not null;

create or replace function public.record_discount_redemption_from_provider(provider_promotion_reference text,target_subscription_id uuid,target_billing_customer_id uuid,undiscounted_minor integer,discounted_minor integer,target_currency text,payment_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target_code public.commercial_discount_codes; created_id uuid;
begin
 if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
 select * into target_code from public.commercial_discount_codes where provider_reference=provider_promotion_reference and revoked_at is null for update;
 if target_code.id is null then return jsonb_build_object('recorded',false,'reason','provider_code_not_managed'); end if;
 insert into public.commercial_discount_redemptions(discount_code_id,billing_customer_id,subscription_id,undiscounted_amount_minor,discounted_amount_minor,currency,provider_reference)
 values(target_code.id,target_billing_customer_id,target_subscription_id,undiscounted_minor,discounted_minor,upper(target_currency),payment_reference)
 on conflict(provider_reference) where provider_reference is not null do nothing returning id into created_id;
 if created_id is not null then
  update public.commercial_discount_codes set redemption_count=redemption_count+1 where id=target_code.id;
  insert into public.commercial_audit_log(action,entity_type,entity_id,after_data,reason) values('discount_code.redeemed','commercial_discount_code',target_code.id::text,jsonb_build_object('subscriptionId',target_subscription_id,'undiscountedAmountMinor',undiscounted_minor,'discountedAmountMinor',discounted_minor),'Verified Stripe checkout redemption');
 end if;
 return jsonb_build_object('recorded',created_id is not null,'discountCodeId',target_code.id);
end $$;
revoke all on function public.record_discount_redemption_from_provider(text,uuid,uuid,integer,integer,text,text) from public,anon,authenticated;
grant execute on function public.record_discount_redemption_from_provider(text,uuid,uuid,integer,integer,text,text) to service_role;
