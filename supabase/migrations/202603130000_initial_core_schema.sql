-- Reconstructed baseline for clean installs.
--
-- The original project was created from supabase/schema.sql in the Dashboard,
-- before CLI migration history was introduced. Later migrations therefore
-- assume these tables already exist. Keep this migration limited to that
-- historical core schema; later migrations own all subsequent changes.

create extension if not exists "pgcrypto";

create table public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  mobile text,
  preferred_auth_method text not null default 'email',
  auth_user_id uuid,
  created_at timestamptz default now(),
  constraint players_auth_contact_check
    check (email is not null or mobile is not null),
  constraint players_preferred_auth_method_check
    check (preferred_auth_method in ('email', 'whatsapp'))
);

create unique index players_email_unique_idx
  on public.players (lower(email))
  where email is not null;

create unique index players_mobile_unique_idx
  on public.players (mobile)
  where mobile is not null;

create table public.fine_types (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cost numeric(10,2) not null,
  created_at timestamptz default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'League',
  created_at timestamptz default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  season_id uuid references public.seasons(id) on delete set null,
  opponent text,
  submitted boolean not null default false,
  created_at timestamptz default now()
);

create table public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  primary key (match_id, player_id)
);

create table public.fines (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  fine_type_id uuid references public.fine_types(id) on delete set null,
  player_name text not null,
  fine_name text not null,
  cost numeric(10,2) not null,
  paid boolean not null default false,
  created_at timestamptz default now()
);

create table public.subs (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  player_name text not null,
  amount numeric(10,2) not null default 0.50,
  paid boolean not null default false,
  created_at timestamptz default now()
);

alter table public.players enable row level security;
alter table public.fine_types enable row level security;
alter table public.seasons enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.fines enable row level security;
alter table public.subs enable row level security;

