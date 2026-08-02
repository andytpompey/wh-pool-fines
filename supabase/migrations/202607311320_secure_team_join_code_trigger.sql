-- Make team join-code generation independent of the caller's search_path.
-- Secure RPCs intentionally use an empty search_path.
create or replace function public.generate_team_join_code()
returns text
language plpgsql
set search_path = ''
as $$
declare
  generated_code text;
  attempt_count integer := 0;
begin
  loop
    attempt_count := attempt_count + 1;
    generated_code := upper(encode(extensions.gen_random_bytes(4), 'hex'));

    exit when not exists (
      select 1 from public.teams t where t.join_code = generated_code
    );

    if attempt_count > 10 then
      raise exception 'Unable to generate a unique team join code';
    end if;
  end loop;

  return generated_code;
end;
$$;

create or replace function public.set_team_join_code()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.join_code is null or btrim(new.join_code) = '' then
    new.join_code = public.generate_team_join_code();
  else
    new.join_code = upper(btrim(new.join_code));
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';
