create or replace function public.set_team_member_role(
  operation_id uuid,
  target_team_id uuid,
  target_membership_id uuid,
  next_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.team_memberships;
  target_membership public.team_memberships;
  existing_response jsonb;
  result jsonb;
begin
  select tm.* into actor_membership
    from public.team_memberships tm
   where tm.team_id = target_team_id
     and tm.player_id = public.current_player_id()
     and tm.status = 'active';
  if auth.uid() is null or actor_membership.role <> 'captain' or public.is_platform_admin() then
    raise exception 'Only the current team captain can change roles';
  end if;
  if next_role not in ('member', 'vice_captain') then
    raise exception 'Captaincy must use the transfer operation';
  end if;

  select response into existing_response from public.idempotent_operations
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = set_team_member_role.operation_id
     and operation_type = 'set_team_member_role' and completed_at is not null;
  if existing_response is not null then return existing_response; end if;

  select tm.* into target_membership from public.team_memberships tm
   where tm.id = target_membership_id and tm.team_id = target_team_id and tm.status = 'active' for update;
  if target_membership.id is null or target_membership.role = 'captain'
     or target_membership.player_id = actor_membership.player_id then
    raise exception 'This member role cannot be changed';
  end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'set_team_member_role') on conflict do nothing;
  if not found then raise exception 'Operation is already in progress or has a different type'; end if;

  update public.team_memberships set role = next_role where id = target_membership_id;
  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
  ) values (
    auth.uid(), target_team_id, 'team.role.changed', 'success', 'team_membership', target_membership_id::text,
    jsonb_build_object('operationId', operation_id, 'previousRole', target_membership.role, 'nextRole', next_role)
  );
  result := jsonb_build_object('success', true, 'operationId', operation_id, 'membershipId', target_membership_id);
  update public.idempotent_operations set response = result, completed_at = now()
   where actor_user_id = auth.uid() and idempotent_operations.operation_id = set_team_member_role.operation_id;
  return result;
end;
$$;

create or replace function public.revoke_team_invite(target_invite_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_invite public.team_invites;
begin
  select ti.* into target_invite from public.team_invites ti
   where ti.id = target_invite_id for update;
  if target_invite.id is null or auth.uid() is null
     or not public.can_manage_team_operations(target_invite.team_id) then
    raise exception 'Pending invite leadership access required';
  end if;
  if target_invite.status <> 'pending' then raise exception 'Only pending invites can be revoked'; end if;
  update public.team_invites set status = 'cancelled', expires_at = now() where id = target_invite_id;
  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome, target_entity_type, target_entity_id, payload
  ) values (
    auth.uid(), target_invite.team_id, 'team_invite.revoked', 'success',
    'team_invite', target_invite_id::text, '{}'::jsonb
  );
  return jsonb_build_object('success', true, 'inviteId', target_invite_id);
end;
$$;

revoke all on function public.set_team_member_role(uuid, uuid, uuid, text) from public, anon;
grant execute on function public.set_team_member_role(uuid, uuid, uuid, text) to authenticated;
revoke all on function public.revoke_team_invite(uuid) from public, anon;
grant execute on function public.revoke_team_invite(uuid) to authenticated;
notify pgrst, 'reload schema';
