create table public.commercial_pilots(
 id uuid primary key default gen_random_uuid(),name text not null,league_name text not null,starts_on date not null,ends_on date not null,state text not null default 'draft' check(state in ('draft','active','completed','cancelled')),
 baseline jsonb not null,success_criteria jsonb not null,renewal_outcome text check(renewal_outcome is null or renewal_outcome in ('renewed','declined','extended','undecided')),renewal_reasons text[],created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),completed_at timestamptz,check(ends_on>starts_on)
);
create table public.commercial_pilot_teams(pilot_id uuid not null references public.commercial_pilots(id) on delete cascade,team_id uuid not null references public.teams(id),playing_cycle_id uuid not null references public.team_playing_cycles(id),division_name text not null default 'Unassigned',captain_sample boolean not null default false,primary key(pilot_id,team_id));
create table public.commercial_pilot_feedback_points(id uuid primary key default gen_random_uuid(),pilot_id uuid not null references public.commercial_pilots(id) on delete cascade,audience text not null check(audience in ('league_committee','captain_group')),scheduled_at timestamptz not null,completed_at timestamptz,aggregate_response jsonb,created_at timestamptz not null default now());
alter table public.commercial_pilots enable row level security; alter table public.commercial_pilot_teams enable row level security; alter table public.commercial_pilot_feedback_points enable row level security;
revoke all on public.commercial_pilots,public.commercial_pilot_teams,public.commercial_pilot_feedback_points from anon,authenticated;

create or replace view public.commercial_pilot_adoption with(security_invoker=false) as
select p.id pilot_id,pt.division_name,pt.team_id,t.name team_name,date_trunc('week',m.date)::date match_week,
 count(distinct m.id) matches_recorded,count(distinct tm.player_id) filter(where tm.status='active') active_members,
 count(distinct case when tm.role='captain' and tm.status='active' then tm.player_id end) active_captains,
 count(distinct sc.id) support_cases
from public.commercial_pilots p join public.commercial_pilot_teams pt on pt.pilot_id=p.id join public.teams t on t.id=pt.team_id
left join public.matches m on m.team_id=pt.team_id and m.date between p.starts_on and p.ends_on
left join public.team_memberships tm on tm.team_id=pt.team_id
left join public.support_cases sc on sc.team_id=pt.team_id and sc.created_at::date between p.starts_on and p.ends_on
group by p.id,pt.division_name,pt.team_id,t.name,date_trunc('week',m.date)::date;
revoke all on public.commercial_pilot_adoption from anon,authenticated;

create or replace function public.create_commercial_pilot(configuration jsonb,reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare created public.commercial_pilots; cycle_ids uuid[]; team_count integer;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 select array_agg(value::uuid) into cycle_ids from jsonb_array_elements_text(configuration->'playingCycleIds');
 if length(btrim(configuration->>'name'))<4 or length(btrim(configuration->>'leagueName'))<3 or (configuration->>'endsOn')::date<=(configuration->>'startsOn')::date or cardinality(cycle_ids)<1 or cardinality(cycle_ids)>500 or length(btrim(reason))<12 then raise exception 'Complete pilot definition and detailed reason are required'; end if;
 select count(distinct team_id) into team_count from public.team_playing_cycles where id=any(cycle_ids);
 if team_count<>cardinality(cycle_ids) then raise exception 'Each pilot team requires one valid playing cycle'; end if;
 insert into public.commercial_pilots(name,league_name,starts_on,ends_on,state,baseline,success_criteria,created_by)
 values(btrim(configuration->>'name'),btrim(configuration->>'leagueName'),(configuration->>'startsOn')::date,(configuration->>'endsOn')::date,'draft',jsonb_build_object('capturedAt',now(),'selectedTeams',team_count,'existingMatches',(select count(*) from public.matches m where m.team_id in(select team_id from public.team_playing_cycles where id=any(cycle_ids))),'activeMembers',(select count(distinct tm.player_id) from public.team_memberships tm where tm.team_id in(select team_id from public.team_playing_cycles where id=any(cycle_ids)) and tm.status='active'),'openSupportCases',(select count(*) from public.support_cases sc where sc.team_id in(select team_id from public.team_playing_cycles where id=any(cycle_ids)) and sc.status not in ('resolved','closed'))),coalesce(configuration->'successCriteria','{}'::jsonb),auth.uid()) returning * into created;
 insert into public.commercial_pilot_teams(pilot_id,team_id,playing_cycle_id,division_name,captain_sample) select created.id,c.team_id,c.id,coalesce(configuration->'divisions'->>c.team_id::text,'Unassigned'),coalesce((configuration->'captainSampleTeamIds')?c.team_id::text,false) from public.team_playing_cycles c where c.id=any(cycle_ids);
 insert into public.commercial_pilot_feedback_points(pilot_id,audience,scheduled_at) values(created.id,'league_committee',(configuration->>'committeeFeedbackAt')::timestamptz),(created.id,'captain_group',(configuration->>'captainFeedbackAt')::timestamptz);
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'pilot.created','commercial_pilot',created.id::text,to_jsonb(created)||jsonb_build_object('playingCycleIds',cycle_ids),btrim(reason));
 return jsonb_build_object('pilotId',created.id,'state',created.state,'baseline',created.baseline,'teamCount',team_count);
end $$;

create or replace function public.update_commercial_pilot_evaluation(target_pilot_id uuid,new_state text,feedback_point_id uuid,aggregate_response jsonb,renewal_outcome text,renewal_reasons text[],reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare pilot public.commercial_pilots;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if new_state not in ('active','completed','cancelled') or length(btrim(reason))<12 then raise exception 'Valid pilot state and detailed reason are required'; end if;
 select * into pilot from public.commercial_pilots where id=target_pilot_id for update; if pilot.id is null then raise exception 'Pilot not found'; end if;
 if feedback_point_id is not null then update public.commercial_pilot_feedback_points set completed_at=now(),aggregate_response=jsonb_strip_nulls(aggregate_response) where id=feedback_point_id and pilot_id=pilot.id; end if;
 if new_state='completed' and (renewal_outcome not in ('renewed','declined','extended','undecided') or cardinality(renewal_reasons)<1) then raise exception 'Renewal outcome and reasons are required to complete a pilot'; end if;
 update public.commercial_pilots set state=new_state,renewal_outcome=case when new_state='completed' then renewal_outcome else commercial_pilots.renewal_outcome end,renewal_reasons=case when new_state='completed' then renewal_reasons else commercial_pilots.renewal_reasons end,completed_at=case when new_state='completed' then now() else completed_at end where id=pilot.id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'pilot.evaluation_updated','commercial_pilot',pilot.id::text,to_jsonb(pilot),jsonb_build_object('state',new_state,'renewalOutcome',renewal_outcome,'renewalReasons',renewal_reasons),btrim(reason));
 return jsonb_build_object('success',true,'pilotId',pilot.id,'state',new_state);
end $$;

create or replace function public.get_commercial_pilot_dashboard() returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.is_platform_admin() then jsonb_build_object('pilots',coalesce((select jsonb_agg(to_jsonb(p) order by p.created_at desc) from public.commercial_pilots p),'[]'::jsonb),'feedbackPoints',coalesce((select jsonb_agg(to_jsonb(f) order by f.scheduled_at) from public.commercial_pilot_feedback_points f),'[]'::jsonb),'adoption',coalesce((select jsonb_agg(to_jsonb(a) order by a.pilot_id,a.division_name,a.team_name,a.match_week) from public.commercial_pilot_adoption a),'[]'::jsonb)) else null end;
$$;
revoke all on function public.create_commercial_pilot(jsonb,text) from public,anon; revoke all on function public.update_commercial_pilot_evaluation(uuid,text,uuid,jsonb,text,text[],text) from public,anon; revoke all on function public.get_commercial_pilot_dashboard() from public,anon;
grant execute on function public.create_commercial_pilot(jsonb,text) to authenticated; grant execute on function public.update_commercial_pilot_evaluation(uuid,text,uuid,jsonb,text,text[],text) to authenticated; grant execute on function public.get_commercial_pilot_dashboard() to authenticated;
