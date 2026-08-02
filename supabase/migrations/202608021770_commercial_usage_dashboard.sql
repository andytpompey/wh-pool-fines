create or replace function public.get_commercial_usage_dashboard() returns jsonb
language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then jsonb_build_object(
   'usageMonths',coalesce((select jsonb_agg(to_jsonb(u) order by u.month desc) from public.commercial_platform_usage_months u),'[]'::jsonb),
   'unitEconomics',coalesce((select jsonb_agg(to_jsonb(e) order by e.month desc) from public.commercial_unit_economics e),'[]'::jsonb)
 ) else null end;
$$;
revoke all on function public.get_commercial_usage_dashboard() from public,anon;
grant execute on function public.get_commercial_usage_dashboard() to authenticated;
