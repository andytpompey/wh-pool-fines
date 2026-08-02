create or replace function public.retire_commercial_offering(target_offering_id uuid, retirement_reason text)
returns public.commercial_offerings
language plpgsql security definer set search_path = '' as $$
declare target public.commercial_offerings; before_row jsonb;
begin
  if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
  if retirement_reason is null or length(btrim(retirement_reason)) < 8 then raise exception 'Retirement reason is required'; end if;
  select * into target from public.commercial_offerings o where o.id = target_offering_id for update;
  before_row := to_jsonb(target);
  if target.id is null or target.state <> 'published' then raise exception 'Published offering not found'; end if;
  update public.commercial_offerings set state = 'retired', retired_at = now() where id = target.id returning * into target;
  insert into public.commercial_audit_log (actor_user_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (auth.uid(), 'offering.retired', 'commercial_offering', target.id::text, before_row, to_jsonb(target), btrim(retirement_reason));
  return target;
end $$;

revoke all on function public.retire_commercial_offering(uuid, text) from public, anon, authenticated;
