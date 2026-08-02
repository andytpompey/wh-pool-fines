create or replace function public.protect_published_catalogue()
returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Published commercial history cannot be deleted'; end if;
 if tg_table_name='commercial_price_versions' then
  if current_setting('roobin.approved_price_binding',true)='true' and to_jsonb(new)-'provider_price_refs'=to_jsonb(old)-'provider_price_refs' then return new; end if;
  raise exception 'Published price versions are immutable; create another version';
 end if;
 if old.state='retired' then raise exception 'Retired offerings are immutable'; end if;
 if new.state='retired' and (to_jsonb(new)-'state'-'retired_at')=(to_jsonb(old)-'state'-'retired_at') then return new; end if;
 raise exception 'Published offerings are immutable; clone another version';
end $$;

create trigger protect_published_offering before update or delete on public.commercial_offerings for each row when (old.state in ('published','retired')) execute function public.protect_published_catalogue();
create trigger protect_published_price before update or delete on public.commercial_price_versions for each row when (old.state='published') execute function public.protect_published_catalogue();

create or replace function public.publish_commercial_offering(target_offering_id uuid,approval_reason text)
returns public.commercial_offerings language plpgsql security definer set search_path='' as $$
declare target public.commercial_offerings;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if approval_reason is null or length(btrim(approval_reason))<8 then raise exception 'Approval reason is required'; end if;
 select * into target from public.commercial_offerings where id=target_offering_id for update;
 if target.id is null then raise exception 'Offering not found'; end if;
 if target.state<>'draft' then raise exception 'Only draft offerings can be published'; end if;
 if cardinality(target.sales_channels)=0 then raise exception 'At least one sales channel is required'; end if;
 if not exists(select 1 from public.entitlement_definitions where id=target.entitlement_definition_id and state='published') then raise exception 'Entitlement definition must be published first'; end if;
 if not exists(select 1 from public.commercial_price_versions where offering_id=target.id and state='published' and effective_from<=now() and (effective_to is null or effective_to>now())) then raise exception 'A current published base price is required'; end if;
 update public.commercial_offerings set state='published',published_at=now() where id=target.id returning * into target;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'offering.published','commercial_offering',target.id::text,to_jsonb(target),btrim(approval_reason));
 return target;
end $$;

create or replace function public.bind_commercial_price_provider(target_price_id uuid,provider_name text,provider_reference text,reason text)
returns public.commercial_price_versions language plpgsql security definer set search_path='' as $$
declare before_row jsonb; changed public.commercial_price_versions;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if provider_name not in ('stripe','app_store','google_play') or length(btrim(provider_reference))<3 or length(btrim(reason))<8 then raise exception 'Provider reference and reason are required'; end if;
 select to_jsonb(p) into before_row from public.commercial_price_versions p where id=target_price_id for update;
 if before_row is null then raise exception 'Price version not found'; end if;
 perform set_config('roobin.approved_price_binding','true',true);
 update public.commercial_price_versions set provider_price_refs=provider_price_refs||jsonb_build_object(provider_name,btrim(provider_reference)) where id=target_price_id returning * into changed;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'price.provider_bound','commercial_price_version',changed.id::text,before_row,to_jsonb(changed),btrim(reason));
 return changed;
end $$;
revoke all on function public.bind_commercial_price_provider(uuid,text,text,text) from public,anon;
grant execute on function public.bind_commercial_price_provider(uuid,text,text,text) to authenticated;
