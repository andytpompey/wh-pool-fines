create or replace function public.update_team_fine_type(
  operation_id uuid, target_team_id uuid, target_fine_type_id uuid,
  fine_name text, fine_cost numeric
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare existing_response jsonb; previous public.fine_types; result jsonb;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then raise exception 'Team leadership access required'; end if;
  if nullif(btrim(fine_name), '') is null or fine_cost < 0 or fine_cost > 100 then raise exception 'Valid fine name and cost are required'; end if;
  select response into existing_response from public.idempotent_operations where actor_user_id=auth.uid() and idempotent_operations.operation_id=update_team_fine_type.operation_id and operation_type='update_team_fine_type' and completed_at is not null;
  if existing_response is not null then return existing_response; end if;
  select * into previous from public.fine_types where id=target_fine_type_id and team_id=target_team_id for update;
  if previous.id is null then raise exception 'Fine type not found'; end if;
  if exists(select 1 from public.fine_types where team_id=target_team_id and id<>target_fine_type_id and lower(name)=lower(btrim(fine_name))) then raise exception 'A fine type with this name already exists'; end if;
  insert into public.idempotent_operations(actor_user_id,operation_id,operation_type) values(auth.uid(),operation_id,'update_team_fine_type') on conflict do nothing;
  if not found then raise exception 'Operation already exists'; end if;
  update public.fine_types set name=btrim(fine_name),cost=fine_cost where id=target_fine_type_id;
  insert into public.audit_logs(actor_user_id,team_id,action,outcome,target_entity_type,target_entity_id,payload) values(auth.uid(),target_team_id,'fine_type.updated','success','fine_type',target_fine_type_id::text,jsonb_build_object('operationId',operation_id,'previousName',previous.name,'previousCost',previous.cost));
  result:=jsonb_build_object('success',true,'operationId',operation_id,'fineTypeId',target_fine_type_id);
  update public.idempotent_operations set response=result,completed_at=now() where actor_user_id=auth.uid() and idempotent_operations.operation_id=update_team_fine_type.operation_id;
  return result;
end; $$;

create or replace function public.save_team_season(
  operation_id uuid, target_team_id uuid, target_season_id uuid,
  season_name text, season_type text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare existing_response jsonb; existing public.seasons; result jsonb;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then raise exception 'Team leadership access required'; end if;
  if nullif(btrim(season_name),'') is null or nullif(btrim(season_type),'') is null then raise exception 'Season name and type are required'; end if;
  select response into existing_response from public.idempotent_operations where actor_user_id=auth.uid() and idempotent_operations.operation_id=save_team_season.operation_id and operation_type='save_team_season' and completed_at is not null;
  if existing_response is not null then return existing_response; end if;
  select * into existing from public.seasons where id=target_season_id for update;
  if existing.id is not null and (existing.team_id<>target_team_id or existing.source is not null) then raise exception 'Imported seasons cannot be edited manually'; end if;
  if exists(select 1 from public.seasons where team_id=target_team_id and id<>target_season_id and lower(name)=lower(btrim(season_name))) then raise exception 'A season with this name already exists'; end if;
  insert into public.idempotent_operations(actor_user_id,operation_id,operation_type) values(auth.uid(),operation_id,'save_team_season') on conflict do nothing;
  if not found then raise exception 'Operation already exists'; end if;
  insert into public.seasons(id,team_id,name,type) values(target_season_id,target_team_id,btrim(season_name),btrim(season_type)) on conflict(id) do update set name=excluded.name,type=excluded.type where seasons.team_id=excluded.team_id and seasons.source is null;
  insert into public.audit_logs(actor_user_id,team_id,action,outcome,target_entity_type,target_entity_id,payload) values(auth.uid(),target_team_id,case when existing.id is null then 'season.created' else 'season.updated' end,'success','season',target_season_id::text,jsonb_build_object('operationId',operation_id,'type',btrim(season_type)));
  result:=jsonb_build_object('success',true,'operationId',operation_id,'seasonId',target_season_id);
  update public.idempotent_operations set response=result,completed_at=now() where actor_user_id=auth.uid() and idempotent_operations.operation_id=save_team_season.operation_id;
  return result;
end; $$;

create or replace function public.guard_season_history_deletion() returns trigger language plpgsql set search_path='' as $$
begin
  if exists(select 1 from public.matches where season_id=old.id) then raise exception 'Season has match history and cannot be deleted'; end if;
  return old;
end; $$;
drop trigger if exists seasons_guard_history_deletion on public.seasons;
create trigger seasons_guard_history_deletion before delete on public.seasons for each row execute function public.guard_season_history_deletion();

revoke all on function public.update_team_fine_type(uuid,uuid,uuid,text,numeric) from public,anon;
grant execute on function public.update_team_fine_type(uuid,uuid,uuid,text,numeric) to authenticated;
revoke all on function public.save_team_season(uuid,uuid,uuid,text,text) from public,anon;
grant execute on function public.save_team_season(uuid,uuid,uuid,text,text) to authenticated;
revoke all on function public.guard_season_history_deletion() from public,anon,authenticated;
notify pgrst,'reload schema';
