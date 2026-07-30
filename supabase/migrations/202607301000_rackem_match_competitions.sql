alter table matches
  add column if not exists source_competition_id text,
  add column if not exists source_competition_name text;

comment on column matches.source_competition_id is
  'RackEm competition identifier when the fixture belongs to a named competition; null for league matches.';

comment on column matches.source_competition_name is
  'Competition title resolved from RackEm; League Match when RackEm supplies no competition identifier.';
