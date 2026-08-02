alter table public.commercial_discount_codes add column provider_reference text;
create unique index commercial_discount_code_provider_reference on public.commercial_discount_codes(provider_reference) where provider_reference is not null;

create or replace function public.commercial_discount_report()
returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then coalesce((select jsonb_agg(jsonb_build_object(
  'id',d.id,'name',d.name,'state',d.state,'type',d.discount_type,'amountMinor',d.amount_minor,'percentage',d.percentage,
  'redemptions',(select count(*) from public.commercial_discount_redemptions r join public.commercial_discount_codes c on c.id=r.discount_code_id where c.discount_id=d.id),
  'grossDiscountMinor',coalesce((select sum(r.undiscounted_amount_minor-r.discounted_amount_minor) from public.commercial_discount_redemptions r join public.commercial_discount_codes c on c.id=r.discount_code_id where c.discount_id=d.id),0),
  'issuedCodes',(select count(*) from public.commercial_discount_codes c where c.discount_id=d.id),
  'providerReady',d.provider_refs?'stripeCoupon'
 ) order by d.created_at desc) from public.commercial_discounts d),'[]'::jsonb) else null end;
$$;
revoke all on function public.commercial_discount_report() from public,anon;
grant execute on function public.commercial_discount_report() to authenticated;
