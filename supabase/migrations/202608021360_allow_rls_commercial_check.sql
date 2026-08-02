-- RLS expressions execute as the calling database role and therefore require
-- execute privilege on this narrow boolean helper. It exposes no billing data.
grant execute on function public.commercial_team_write_allowed(uuid, text) to authenticated;
