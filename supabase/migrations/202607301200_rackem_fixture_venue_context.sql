alter table matches
  add column if not exists source_team_role text,
  add column if not exists source_venue_id text,
  add column if not exists source_team_venue_id text,
  add column if not exists source_team_venue_name text;

comment on column matches.source_team_role is
  'RackEm fixture role for this team: home or away. This is independent of the physical fixture venue.';

comment on column matches.source_venue_id is
  'RackEm venue identifier assigned to the fixture.';

comment on column matches.source_team_venue_id is
  'RackEm registered venue identifier for the imported team at the time of refresh.';

comment on column matches.source_team_venue_name is
  'RackEm registered venue name for the imported team at the time of refresh.';
