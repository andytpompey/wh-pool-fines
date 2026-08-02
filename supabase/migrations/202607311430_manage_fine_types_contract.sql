create or replace function public.create_team_fine_type(
  target_team_id uuid,
  fine_name text,
  fine_cost numeric
)
returns public.fine_types
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_type public.fine_types;
begin
  if auth.uid() is null or not public.can_manage_team_operations(target_team_id) then
    raise exception 'Team leadership access required';
  end if;
  if nullif(btrim(fine_name), '') is null then
    raise exception 'Fine name is required';
  end if;
  if fine_cost is null or fine_cost < 0 or fine_cost > 100 then
    raise exception 'Fine cost must be between 0 and 100';
  end if;
  if exists (
    select 1 from public.fine_types ft
    where ft.team_id = target_team_id and lower(ft.name) = lower(btrim(fine_name))
  ) then
    raise exception 'A fine type with this name already exists';
  end if;

  insert into public.fine_types (team_id, name, cost)
  values (target_team_id, btrim(fine_name), fine_cost)
  returning * into created_type;
  return created_type;
end;
$$;

revoke all on function public.create_team_fine_type(uuid, text, numeric) from public, anon;
grant execute on function public.create_team_fine_type(uuid, text, numeric) to authenticated;
notify pgrst, 'reload schema';
