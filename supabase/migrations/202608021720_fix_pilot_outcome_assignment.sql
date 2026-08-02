create or replace function public.update_commercial_pilot_evaluation(target_pilot_id uuid,new_state text,feedback_point_id uuid,aggregate_response jsonb,renewal_outcome text,renewal_reasons text[],reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare pilot public.commercial_pilots;
begin
 if not public.is_platform_admin() then raise exception 'Commercial administrator access required'; end if;
 if new_state not in ('active','completed','cancelled') or length(btrim(reason))<12 then raise exception 'Valid pilot state and detailed reason are required'; end if;
 select * into pilot from public.commercial_pilots where id=target_pilot_id for update; if pilot.id is null then raise exception 'Pilot not found'; end if;
 if feedback_point_id is not null then update public.commercial_pilot_feedback_points f set completed_at=now(),aggregate_response=jsonb_strip_nulls($4) where f.id=$3 and f.pilot_id=pilot.id; end if;
 if new_state='completed' and ($5 not in ('renewed','declined','extended','undecided') or cardinality($6)<1) then raise exception 'Renewal outcome and reasons are required to complete a pilot'; end if;
 update public.commercial_pilots cp set state=new_state,renewal_outcome=case when new_state='completed' then $5 else cp.renewal_outcome end,renewal_reasons=case when new_state='completed' then $6 else cp.renewal_reasons end,completed_at=case when new_state='completed' then now() else cp.completed_at end where cp.id=pilot.id;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'pilot.evaluation_updated','commercial_pilot',pilot.id::text,to_jsonb(pilot),jsonb_build_object('state',new_state,'renewalOutcome',$5,'renewalReasons',$6),btrim(reason));
 return jsonb_build_object('success',true,'pilotId',pilot.id,'state',new_state);
end $$;
