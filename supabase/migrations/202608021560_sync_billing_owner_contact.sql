create or replace function public.sync_billing_owner_contact()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.billing_customer_contacts(billing_customer_id,user_id,role,status,verified_at)
 values(new.id,new.owner_user_id,'owner','active',now())
 on conflict(billing_customer_id,user_id) do update set role='owner',status='active',verified_at=coalesce(public.billing_customer_contacts.verified_at,now()),updated_at=now();
 return new;
end $$;
create trigger sync_billing_owner_contact_after_write after insert or update of owner_user_id on public.billing_customers for each row execute function public.sync_billing_owner_contact();
