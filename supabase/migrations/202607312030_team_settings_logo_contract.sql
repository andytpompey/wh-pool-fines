update storage.buckets
set allowed_mime_types = array['image/jpeg','image/webp'], file_size_limit = 1048576
where id = 'team-logos';

create or replace function public.update_team_settings(
  operation_id uuid, target_team_id uuid, team_name text,
  use_subs boolean, void_driver_subs boolean, configured_sub_amount numeric,
  configured_logo_url text default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare existing_response jsonb; result jsonb;
begin
 if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then raise exception 'Team leadership access required'; end if;
 if nullif(btrim(team_name),'') is null or length(btrim(team_name))>120 then raise exception 'Valid team name is required'; end if;
 if configured_sub_amount is null or configured_sub_amount<0 or configured_sub_amount>100 then raise exception 'Subs amount must be between 0 and 100'; end if;
 if configured_logo_url is not null and configured_logo_url not like '%/storage/v1/object/public/team-logos/'||target_team_id::text||'/%' then raise exception 'Logo must use this team storage folder'; end if;
 select response into existing_response from public.idempotent_operations where actor_user_id=auth.uid() and idempotent_operations.operation_id=update_team_settings.operation_id and operation_type='update_team_settings' and completed_at is not null;
 if existing_response is not null then return existing_response; end if;
 insert into public.idempotent_operations(actor_user_id,operation_id,operation_type) values(auth.uid(),operation_id,'update_team_settings') on conflict do nothing;
 if not found then raise exception 'Operation already exists'; end if;
 update public.teams set name=btrim(team_name),subs_enabled=use_subs,drivers_void_subs=use_subs and void_driver_subs,sub_amount=configured_sub_amount,logo_url=nullif(configured_logo_url,'') where id=target_team_id;
 if not found then raise exception 'Team not found'; end if;
 insert into public.audit_logs(actor_user_id,team_id,action,outcome,target_entity_type,target_entity_id,payload) values(auth.uid(),target_team_id,'team.settings.updated','success','team',target_team_id::text,jsonb_build_object('operationId',operation_id,'subsEnabled',use_subs,'driversVoidSubs',use_subs and void_driver_subs,'subAmount',configured_sub_amount,'hasLogo',configured_logo_url is not null));
 result:=jsonb_build_object('success',true,'operationId',operation_id,'teamId',target_team_id);
 update public.idempotent_operations set response=result,completed_at=now() where actor_user_id=auth.uid() and idempotent_operations.operation_id=update_team_settings.operation_id;
 return result;
end; $$;
revoke all on function public.update_team_settings(uuid,uuid,text,boolean,boolean,numeric,text) from public,anon;
grant execute on function public.update_team_settings(uuid,uuid,text,boolean,boolean,numeric,text) to authenticated;
notify pgrst,'reload schema';
