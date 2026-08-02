create or replace function public.update_service_incident(target_incident_id uuid,new_status text,public_message text,mitigation text,post_incident_actions text[],notify_affected boolean,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare before_row public.service_incidents; changed public.service_incidents; update_id uuid; queued integer:=0;
begin
 if not public.is_platform_admin() then raise exception 'Incident administrator access required'; end if;
 if new_status not in ('investigating','identified','monitoring','resolved') or length(btrim(public_message))<10 or length(btrim(reason))<8 then raise exception 'Incident status, public update and reason are required'; end if;
 select * into before_row from public.service_incidents where id=target_incident_id for update;
 if before_row.id is null then raise exception 'Incident not found'; end if;
 if before_row.status='resolved' then raise exception 'Resolved incidents are immutable'; end if;
 if new_status='resolved' and (length(btrim(coalesce(mitigation,'')))<8 or cardinality(post_incident_actions)<1) then raise exception 'Resolution requires mitigation and tracked post-incident actions'; end if;
 update public.service_incidents set status=new_status,public_message=btrim($3),mitigation=nullif(btrim($4),''),post_incident_actions=coalesce($5,'{}'),resolved_at=case when new_status='resolved' then now() else null end,updated_at=now() where id=target_incident_id returning * into changed;
 insert into public.service_incident_updates(incident_id,status,public_message,mitigation,created_by) values(changed.id,new_status,changed.public_message,changed.mitigation,auth.uid()) returning id into update_id;
 if notify_affected and changed.impact in ('major','critical') then queued:=public.queue_material_incident_notifications(changed.id,update_id,jsonb_build_object('incidentId',changed.id,'title',changed.title,'impact',changed.impact,'status',changed.status,'message',changed.public_message,'mitigation',changed.mitigation,'components',changed.affected_components)); end if;
 insert into public.commercial_audit_log(actor_user_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'incident.updated','service_incident',changed.id::text,to_jsonb(before_row),to_jsonb(changed)||jsonb_build_object('notificationsQueued',queued),btrim(reason));
 return jsonb_build_object('incidentId',changed.id,'status',changed.status,'updateId',update_id,'notificationsQueued',queued);
end $$;
