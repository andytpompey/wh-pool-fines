create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid null default auth.uid() references auth.users(id) on delete set null,
  team_id uuid not null references public.teams(id) on delete cascade,
  action text not null,
  outcome text not null default 'success' check (outcome in ('success', 'failure')),
  actor_role_context jsonb not null default '{}'::jsonb,
  target_entity_type text null,
  target_entity_id text null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_team_created_at_idx on public.audit_logs(team_id, created_at desc);
create index if not exists audit_logs_action_idx on public.audit_logs(action);
create index if not exists audit_logs_actor_user_idx on public.audit_logs(actor_user_id);

alter table public.audit_logs enable row level security;

create policy "audit logs insert for members" on public.audit_logs
for insert
with check (
  exists (
    select 1
    from public.team_memberships tm
    join public.players p on p.id = tm.player_id
    where tm.team_id = audit_logs.team_id
      and tm.status = 'active'
      and p.user_id = auth.uid()
  )
  or exists (
    select 1
    from public.app_users au
    where au.id = auth.uid()
      and au.is_platform_admin = true
  )
);

create policy "audit logs select for platform admins" on public.audit_logs
for select
using (
  exists (
    select 1
    from public.app_users au
    where au.id = auth.uid()
      and au.is_platform_admin = true
  )
);
