alter table if exists teams
  add column if not exists subs_enabled boolean not null default true,
  add column if not exists drivers_void_subs boolean not null default true;

alter table if exists matches
  add column if not exists venue text not null default 'home';

alter table if exists matches
  drop constraint if exists matches_venue_check;

alter table if exists matches
  add constraint matches_venue_check check (venue in ('home', 'away'));

alter table if exists match_players
  add column if not exists is_driver boolean not null default false;
