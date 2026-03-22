alter table if exists teams
  add column if not exists unlock_code_salt text,
  add column if not exists unlock_code_hash_algorithm text not null default 'pbkdf2-sha256',
  add column if not exists unlock_code_hash_iterations integer not null default 210000,
  add column if not exists unlock_code_version integer not null default 1,
  add column if not exists unlock_code_reset_requested_at timestamptz;

comment on column teams.unlock_code_salt is 'Random salt used for non-reversible team unlock-code hashing.';
comment on column teams.unlock_code_hash_algorithm is 'Algorithm identifier for team unlock-code hashing metadata.';
comment on column teams.unlock_code_hash_iterations is 'Work factor used when deriving the stored team unlock-code hash.';
comment on column teams.unlock_code_version is 'Application-managed version for team unlock-code hashing and rotation logic.';
comment on column teams.unlock_code_reset_requested_at is 'Timestamp of the latest unlock-code reset/change workflow completion.';
