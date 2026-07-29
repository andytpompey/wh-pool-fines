alter table teams
  add column if not exists rackem_import_enabled boolean not null default false,
  add column if not exists rackem_league_slug text,
  add column if not exists rackem_league_name text,
  add column if not exists rackem_team_id text,
  add column if not exists rackem_team_name text,
  add column if not exists rackem_team_url text;

alter table seasons
  add column if not exists source text,
  add column if not exists source_league_slug text,
  add column if not exists source_season_team_id text,
  add column if not exists source_url text,
  add column if not exists source_last_refreshed_at timestamptz,
  add column if not exists source_last_refresh_status text;

create unique index if not exists seasons_rackem_source_unique_idx
  on seasons(team_id, source, source_season_team_id)
  where source is not null and source_season_team_id is not null;

alter table matches
  add column if not exists source text,
  add column if not exists source_identity text,
  add column if not exists source_scorecard_id text,
  add column if not exists source_matchday text,
  add column if not exists source_status text,
  add column if not exists source_home_score integer,
  add column if not exists source_away_score integer,
  add column if not exists source_home_team_id text,
  add column if not exists source_away_team_id text,
  add column if not exists source_venue_name text,
  add column if not exists source_last_seen_at timestamptz;

create unique index if not exists matches_rackem_source_unique_idx
  on matches(team_id, source, source_identity)
  where source is not null and source_identity is not null;
