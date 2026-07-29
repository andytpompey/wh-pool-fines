alter table if exists players
  add column if not exists dashboard_season_preferences jsonb not null default '{}'::jsonb;
