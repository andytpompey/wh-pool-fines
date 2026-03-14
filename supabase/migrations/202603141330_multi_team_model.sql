create extension if not exists "pgcrypto";

-- Player profile upgrade: convert players into global profiles while preserving
-- compatibility with legacy columns used by existing UI flows.
alter table if exists players add column if not exists display_name text;
alter table if exists players add column if not exists user_id uuid;
alter table if exists players add column if not exists receive_team_notifications boolean not null default true;

update players
set display_name = coalesce(display_name, name)
where display_name is null;

update players
set user_id = auth_user_id
where user_id is null
  and auth_user_id is not null;

update players
set email = concat('player-', id::text, '@placeholder.local')
where email is null or btrim(email) = '';

alter table if exists players alter column display_name set not null;
alter table if exists players alter column email set not null;

-- Keep legacy and new naming/link columns in sync for build compatibility.
create or replace function sync_player_profile_columns()
returns trigger
language plpgsql
as $$
begin
  if new.display_name is null or btrim(new.display_name) = '' then
    new.display_name = coalesce(new.name, 'Unknown Player');
  end if;

  if new.name is null or btrim(new.name) = '' then
    new.name = new.display_name;
  end if;

  if new.user_id is null and new.auth_user_id is not null then
    new.user_id = new.auth_user_id;
  end if;

  if new.auth_user_id is null and new.user_id is not null then
    new.auth_user_id = new.user_id;
  end if;

  if new.email is null or btrim(new.email) = '' then
    new.email = concat('player-', coalesce(new.id, gen_random_uuid())::text, '@placeholder.local');
  end if;

  return new;
end;
$$;

drop trigger if exists players_sync_profile_columns on players;
create trigger players_sync_profile_columns
before insert or update on players
for each row execute function sync_player_profile_columns();

drop index if exists players_email_unique_idx;
create unique index if not exists players_email_unique_idx on players (lower(email));
create unique index if not exists players_user_id_unique_idx on players (user_id) where user_id is not null;
create index if not exists players_display_name_idx on players (display_name);

-- Team model
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text unique not null,
  created_by uuid null references players(id) on delete set null,
  created_at timestamptz not null default now()
);

create or replace function generate_team_join_code()
returns text
language plpgsql
as $$
declare
  generated_code text;
  attempt_count integer := 0;
begin
  loop
    attempt_count := attempt_count + 1;
    generated_code := upper(encode(gen_random_bytes(4), 'hex'));

    exit when not exists (
      select 1 from teams t where t.join_code = generated_code
    );

    if attempt_count > 10 then
      raise exception 'Unable to generate a unique team join code';
    end if;
  end loop;

  return generated_code;
end;
$$;

create or replace function set_team_join_code()
returns trigger
language plpgsql
as $$
begin
  if new.join_code is null or btrim(new.join_code) = '' then
    new.join_code = generate_team_join_code();
  else
    new.join_code = upper(btrim(new.join_code));
  end if;

  return new;
end;
$$;

drop trigger if exists teams_set_join_code on teams;
create trigger teams_set_join_code
before insert or update of join_code on teams
for each row execute function set_team_join_code();

create index if not exists teams_join_code_idx on teams (join_code);
create index if not exists teams_created_by_idx on teams (created_by);

create table if not exists team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  role text not null check (role in ('captain','admin','member')),
  status text not null default 'active' check (status in ('active','invited','removed')),
  joined_at timestamptz not null default now(),
  unique(team_id, player_id)
);

create index if not exists team_memberships_team_id_idx on team_memberships (team_id);
create index if not exists team_memberships_player_id_idx on team_memberships (player_id);
create index if not exists team_memberships_role_status_idx on team_memberships (role, status);

create table if not exists team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  email text not null,
  player_id uuid null references players(id) on delete set null,
  invited_by_player_id uuid null references players(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','expired','cancelled')),
  token text unique not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz null
);

create index if not exists team_invites_team_id_idx on team_invites (team_id);
create index if not exists team_invites_player_id_idx on team_invites (player_id);
create index if not exists team_invites_email_idx on team_invites (lower(email));
create index if not exists team_invites_status_idx on team_invites (status);

-- RLS defaults mirror existing open-access policy until auth model is tightened.
alter table teams enable row level security;
alter table team_memberships enable row level security;
alter table team_invites enable row level security;

create policy "allow all" on teams for all using (true) with check (true);
create policy "allow all" on team_memberships for all using (true) with check (true);
create policy "allow all" on team_invites for all using (true) with check (true);
