-- White Horse Pool Fines — Supabase Schema
-- Run this entire file in: Supabase Dashboard → SQL Editor → New Query

create extension if not exists "pgcrypto";

-- ── Core domain tables ───────────────────────────────────────────────────────
create table if not exists players (
  id                     uuid primary key default gen_random_uuid(),
  name                   text not null,
  display_name           text not null,
  email                  text not null,
  mobile                 text unique,
  preferred_auth_method  text not null default 'email' check (preferred_auth_method in ('email', 'whatsapp')),
  auth_user_id           uuid,
  user_id                uuid,
  receive_team_notifications boolean not null default true,
  created_at             timestamptz default now(),
  constraint players_auth_contact_check check (email is not null)
);

create table if not exists fine_types (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  cost        numeric(10,2) not null,
  created_at  timestamptz default now()
);

create table if not exists seasons (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        text not null default 'League',
  created_at  timestamptz default now()
);

create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  season_id   uuid references seasons(id) on delete set null,
  opponent    text,
  submitted   boolean not null default false,
  created_at  timestamptz default now()
);

create table if not exists match_players (
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid not null references players(id) on delete cascade,
  primary key (match_id, player_id)
);

create table if not exists fines (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references matches(id) on delete cascade,
  player_id     uuid references players(id) on delete set null,
  fine_type_id  uuid references fine_types(id) on delete set null,
  player_name   text not null,
  fine_name     text not null,
  cost          numeric(10,2) not null,
  paid          boolean not null default false,
  created_at    timestamptz default now()
);

create table if not exists subs (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid references players(id) on delete set null,
  player_name text not null,
  amount      numeric(10,2) not null default 0.50,
  paid        boolean not null default false,
  created_at  timestamptz default now()
);

-- ── Auth-linked app profile table ────────────────────────────────────────────
create table if not exists app_users (
  id                     uuid primary key references auth.users(id) on delete cascade,
  email                  text,
  mobile                 text,
  preferred_auth_method  text not null default 'email',
  player_id              uuid references players(id) on delete set null,
  role                   text not null default 'member',
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint app_users_preferred_auth_method_check check (preferred_auth_method in ('email', 'whatsapp'))
);

create unique index if not exists app_users_email_unique_idx on app_users (lower(email)) where email is not null;
create unique index if not exists app_users_mobile_unique_idx on app_users (mobile) where mobile is not null;
create unique index if not exists app_users_player_unique_idx on app_users (player_id) where player_id is not null;

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_users_set_updated_at on app_users;
create trigger app_users_set_updated_at
before update on app_users
for each row execute function set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table players enable row level security;
alter table fine_types enable row level security;
alter table seasons enable row level security;
alter table matches enable row level security;
alter table match_players enable row level security;
alter table fines        enable row level security;
alter table subs         enable row level security;

-- Allow all operations for anon (unauthenticated) role
create policy "allow all" on players      for all using (true) with check (true);
create policy "allow all" on fine_types   for all using (true) with check (true);
create policy "allow all" on seasons      for all using (true) with check (true);
create policy "allow all" on matches      for all using (true) with check (true);
create policy "allow all" on match_players for all using (true) with check (true);
create policy "allow all" on fines        for all using (true) with check (true);
create policy "allow all" on subs         for all using (true) with check (true);


-- Multi-team domain tables
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text unique not null,
  created_by uuid null references players(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  role text not null check (role in ('captain','admin','member')),
  status text not null default 'active' check (status in ('active','invited','removed')),
  joined_at timestamptz not null default now(),
  unique(team_id, player_id)
);

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

alter table teams enable row level security;
alter table team_memberships enable row level security;
alter table team_invites enable row level security;

create policy "allow all" on teams            for all using (true) with check (true);
create policy "allow all" on team_memberships for all using (true) with check (true);
create policy "allow all" on team_invites     for all using (true) with check (true);


-- Add auth columns for existing projects running earlier schema versions
alter table players add column if not exists email text;
alter table players add column if not exists mobile text;
alter table players add column if not exists preferred_auth_method text not null default 'email';
alter table players add column if not exists auth_user_id uuid;
alter table players add column if not exists display_name text;
alter table players add column if not exists user_id uuid;
alter table players add column if not exists receive_team_notifications boolean not null default true;

update players set display_name = coalesce(display_name, name) where display_name is null;
update players set user_id = auth_user_id where user_id is null and auth_user_id is not null;
update players set email = concat('player-', id::text, '@placeholder.local') where email is null or btrim(email) = '';

alter table players alter column display_name set not null;
alter table players alter column email set not null;

create unique index if not exists players_email_unique_idx on players (lower(email)) where email is not null;
create unique index if not exists players_mobile_unique_idx on players (mobile) where mobile is not null;
create unique index if not exists players_user_id_unique_idx on players (user_id) where user_id is not null;
create index if not exists players_display_name_idx on players (display_name);

create index if not exists teams_join_code_idx on teams (join_code);
create index if not exists teams_created_by_idx on teams (created_by);
create index if not exists team_memberships_team_id_idx on team_memberships (team_id);
create index if not exists team_memberships_player_id_idx on team_memberships (player_id);
create index if not exists team_invites_team_id_idx on team_invites (team_id);
create index if not exists team_invites_player_id_idx on team_invites (player_id);
create index if not exists team_invites_email_idx on team_invites (lower(email));

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

alter table players drop constraint if exists players_preferred_auth_method_check;
alter table players add constraint players_preferred_auth_method_check
  check (preferred_auth_method in ('email', 'whatsapp'));
