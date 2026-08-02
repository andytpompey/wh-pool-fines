create or replace function public.change_team_unlock_code(
  grant_token uuid, new_unlock_code text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare consumed public.protected_action_grants; rotated_at timestamptz:=now();
begin
 if auth.uid() is null or new_unlock_code is null or new_unlock_code !~ '^[0-9]{4,12}$' then raise exception 'A new 4 to 12 digit unlock code is required'; end if;
 update public.protected_action_grants g set consumed_at=now() where g.token=grant_token and g.actor_user_id=auth.uid() and g.action='change_unlock_code' and g.consumed_at is null and g.expires_at>now() returning g.* into consumed;
 if consumed.token is null or not public.is_admin_of_team(consumed.team_id) then raise exception 'Unlock grant is invalid or expired'; end if;
 update public.teams set unlock_code_hash=extensions.crypt(new_unlock_code,extensions.gen_salt('bf',12)),unlock_code_salt=null,unlock_code_hash_algorithm='bcrypt',unlock_code_hash_iterations=12,unlock_code_version=2,unlock_code_reset_required=false,unlock_code_last_rotated_at=rotated_at,unlock_code_reset_requested_at=null where id=consumed.team_id;
 delete from public.unlock_verification_attempts where team_id=consumed.team_id;
 delete from public.protected_action_grants where team_id=consumed.team_id and token<>grant_token;
 insert into public.audit_logs(actor_user_id,team_id,action,outcome,target_entity_type,target_entity_id,payload) values(auth.uid(),consumed.team_id,'unlock_code.changed','success','team',consumed.team_id::text,jsonb_build_object('version',2,'rotatedAt',rotated_at));
 return jsonb_build_object('success',true,'teamId',consumed.team_id,'rotatedAt',rotated_at);
end; $$;
revoke all on function public.change_team_unlock_code(uuid,text) from public,anon;
grant execute on function public.change_team_unlock_code(uuid,text) to authenticated;
notify pgrst,'reload schema';
