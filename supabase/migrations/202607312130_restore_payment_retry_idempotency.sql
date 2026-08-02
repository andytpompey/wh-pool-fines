create or replace function public.update_payment_batch(
  operation_id uuid,
  target_team_id uuid,
  items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_response jsonb;
  item jsonb;
  affected integer;
  updated_count integer := 0;
  result jsonb;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Team leadership access required';
  end if;

  -- A completed operation wins over payload validation. Clients may safely retry
  -- after losing the original response without replaying the complete payload.
  select response into existing_response
    from public.idempotent_operations
   where actor_user_id = auth.uid()
     and idempotent_operations.operation_id = update_payment_batch.operation_id
     and operation_type = 'update_payment_batch'
     and completed_at is not null;
  if existing_response is not null then
    return existing_response;
  end if;

  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items) = 0 then
    raise exception 'At least one payment item is required';
  end if;

  insert into public.idempotent_operations (actor_user_id, operation_id, operation_type)
  values (auth.uid(), operation_id, 'update_payment_batch')
  on conflict do nothing;
  if not found then
    raise exception 'Operation is already in progress or has a different type';
  end if;

  for item in select value from jsonb_array_elements(items)
  loop
    if item ->> 'kind' = 'fine' then
      update public.fines f
         set paid = (item ->> 'paid')::boolean
        from public.matches m
       where f.id = (item ->> 'id')::uuid
         and m.id = f.match_id
         and m.team_id = target_team_id;
    elsif item ->> 'kind' = 'sub' then
      update public.subs s
         set paid = (item ->> 'paid')::boolean
        from public.matches m
       where s.id = (item ->> 'id')::uuid
         and m.id = s.match_id
         and m.team_id = target_team_id;
    else
      raise exception 'Unsupported payment item';
    end if;

    get diagnostics affected = row_count;
    if affected <> 1 then
      raise exception 'Payment item not found in team';
    end if;
    updated_count := updated_count + 1;
  end loop;

  insert into public.audit_logs (
    actor_user_id, team_id, action, outcome,
    target_entity_type, target_entity_id, payload
  ) values (
    auth.uid(), target_team_id, 'payments.status.changed', 'success',
    'payment_batch', operation_id::text,
    jsonb_build_object('operationId', operation_id, 'updatedCount', updated_count, 'items', items)
  );

  result := jsonb_build_object(
    'success', true,
    'operationId', operation_id,
    'updatedCount', updated_count
  );
  update public.idempotent_operations
     set response = result, completed_at = now()
   where actor_user_id = auth.uid()
     and idempotent_operations.operation_id = update_payment_batch.operation_id;
  return result;
end;
$$;

revoke all on function public.update_payment_batch(uuid, uuid, jsonb) from public, anon;
grant execute on function public.update_payment_batch(uuid, uuid, jsonb) to authenticated;
