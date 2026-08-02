create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  case_type text not null check (case_type in ('support','league_enquiry','privacy','billing','incident')),
  status text not null default 'open' check (status in ('open','acknowledged','waiting_customer','resolved','closed')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  contact_name text,
  contact_email text not null,
  team_or_league_name text,
  approximate_team_count integer check (approximate_team_count is null or approximate_team_count between 1 and 10000),
  subject text not null,
  description text not null,
  consent_to_contact boolean not null default true,
  source text not null default 'public_web',
  owner_user_id uuid references auth.users(id),
  team_id uuid references public.teams(id) on delete set null,
  assigned_to uuid references auth.users(id),
  response_due_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.public_request_limits (
  request_hash text not null,
  request_kind text not null,
  window_started_at timestamptz not null,
  request_count integer not null default 1,
  primary key (request_hash,request_kind,window_started_at)
);

create table public.service_incidents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  status text not null check (status in ('investigating','identified','monitoring','resolved')),
  impact text not null check (impact in ('none','minor','major','critical')),
  public_message text not null,
  started_at timestamptz not null,
  resolved_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.service_components (
  code text primary key,
  name text not null,
  status text not null check (status in ('operational','degraded','partial_outage','major_outage','maintenance')),
  message text,
  updated_at timestamptz not null default now()
);
insert into public.service_components (code,name,status) values
 ('web','RooBin web','operational'),('api','RooBin API','operational'),('ios','RooBin iPhone app','operational'),('email','Transactional email','operational');

alter table public.support_cases enable row level security;
alter table public.public_request_limits enable row level security;
alter table public.service_incidents enable row level security;
alter table public.service_components enable row level security;
revoke all on public.support_cases,public.public_request_limits from anon,authenticated;
create policy "public incident history" on public.service_incidents for select to anon,authenticated using (true);
create policy "public component status" on public.service_components for select to anon,authenticated using (true);
grant select on public.service_incidents,public.service_components to anon,authenticated;

create or replace function public.commercial_support_summary()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when public.is_platform_admin() then jsonb_build_object(
    'openCases',(select count(*) from public.support_cases where status not in ('resolved','closed')),
    'urgentCases',(select count(*) from public.support_cases where priority='urgent' and status not in ('resolved','closed')),
    'overdueCases',(select count(*) from public.support_cases where response_due_at<now() and status not in ('resolved','closed'))
  ) else null end;
$$;
revoke all on function public.commercial_support_summary() from public,anon;
grant execute on function public.commercial_support_summary() to authenticated;

comment on table public.support_cases is 'Minimal support and league-enquiry case data; never collect unlock codes or payment instrument data.';
