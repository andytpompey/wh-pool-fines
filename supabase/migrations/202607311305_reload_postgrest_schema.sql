-- Refresh the hosted PostgREST schema cache after adding or replacing RPCs.
-- This does not modify application data.
notify pgrst, 'reload schema';
