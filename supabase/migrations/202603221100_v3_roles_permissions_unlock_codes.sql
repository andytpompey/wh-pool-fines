create extension if not exists "pgcrypto";

alter table if exists app_users
  add column if not exists is_platform_admin boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists teams
  add column if not exists unlock_code_hash text,
  add column if not exists unlock_code_last_rotated_at timestamptz,
  add column if not exists unlock_code_reset_required boolean not null default true;

alter table if exists team_memberships
  drop constraint if exists team_memberships_role_check;

update team_memberships
set role = 'vice_captain'
where role = 'admin';

alter table if exists team_memberships
  add constraint team_memberships_role_check
  check (role in ('captain', 'vice_captain', 'member'));

comment on column app_users.is_platform_admin is 'Platform-wide Roo Bin support/admin entitlement. Distinct from team roles.';
comment on column teams.unlock_code_hash is 'Hashed team unlock code for protected actions. Raw code must never be stored or exposed.';
comment on column teams.unlock_code_reset_required is 'True when the team must set a new unlock code before protected actions can be used.';
comment on column teams.unlock_code_last_rotated_at is 'Timestamp of the most recent unlock-code set or rotation.';
comment on column team_memberships.role is 'Team-scoped role. Valid values: captain, vice_captain, member.';
