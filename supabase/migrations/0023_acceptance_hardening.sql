-- P0/P1 acceptance hardening: storage evidence policies, realtime, approval separation and reminders.
begin;

-- Evidence file paths are organization/laboratory/evidence-id/file.
do $$ begin
 if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='storage_evidence_read') then
  create policy storage_evidence_read on storage.objects for select to authenticated using(
   bucket_id='documents' and exists(
    select 1 from public.evidence_files f join public.evidence_items e on e.id=f.evidence_id
    where f.storage_path=name and public.can_read_scope(e.organization_id,e.laboratory_id)
   )
  );
 end if;
 if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='storage_evidence_insert') then
  create policy storage_evidence_insert on storage.objects for insert to authenticated with check(
   bucket_id='documents' and public.has_permission('create') and exists(
    select 1 from public.profiles p where p.id=auth.uid() and p.status='approved'
      and (storage.foldername(name))[1]=p.organization_id::text
      and (storage.foldername(name))[2]=p.laboratory_id::text
   )
  );
 end if;
end $$;

-- Approver must differ from evidence owner and expert reviewer.
create or replace function public.approve_evidence(target_evidence uuid,target_comment text)
returns void language plpgsql security definer set search_path=public as $$
declare e public.evidence_items;begin
 if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;
 if target_comment is null or length(btrim(target_comment))<3 then raise exception 'COMMENT_REQUIRED';end if;
 select * into e from public.evidence_items where id=target_evidence for update;
 if e.id is null then raise exception 'EVIDENCE_NOT_FOUND';end if;
 if e.owner_id=auth.uid() or e.reviewer_id=auth.uid() then raise exception 'SEPARATION_OF_DUTIES';end if;
 if e.status<>'verified' then raise exception 'EXPERT_VERIFICATION_REQUIRED';end if;
 if exists(select 1 from public.evidence_validations where evidence_id=e.id and result='FAIL') then raise exception 'VALIDATION_FAILED';end if;
 update public.evidence_items set approver_id=auth.uid(),status='approved',approved_at=now(),updated_at=now() where id=e.id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,details) values(auth.uid(),'evidence_approved','evidence_item',e.id::text,jsonb_build_object('comment',target_comment));
end$$;
revoke all on function public.approve_evidence(uuid,text) from public;grant execute on function public.approve_evidence(uuid,text) to authenticated;

-- Expert review verifies; it no longer performs final approval.
create or replace function public.submit_expert_review(target_evidence uuid,target_decision text,target_comment text)
returns void language plpgsql security definer set search_path=public as $$
declare e public.evidence_items;begin
 select * into e from public.evidence_items where id=target_evidence for update;
 if e.id is null then raise exception 'EVIDENCE_NOT_FOUND';end if;
 if e.owner_id=auth.uid() then raise exception 'SEPARATION_OF_DUTIES';end if;
 if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;
 if target_decision not in('approved','rejected','needs_supplement') then raise exception 'INVALID_DECISION';end if;
 if exists(select 1 from public.evidence_validations where evidence_id=e.id and result='FAIL') and target_decision='approved' then raise exception 'VALIDATION_FAILED';end if;
 insert into public.expert_reviews(evidence_id,reviewer_id,decision,comment) values(e.id,auth.uid(),target_decision,target_comment)
 on conflict(evidence_id,reviewer_id) do update set decision=excluded.decision,comment=excluded.comment,reviewed_at=now();
 update public.evidence_items set reviewer_id=auth.uid(),status=case target_decision when 'approved' then 'verified' when 'rejected' then 'rejected' else 'needs_supplement' end,updated_at=now() where id=e.id;
end$$;

-- Automatic daily reminders callable by scheduler/cron.
create or replace function public.generate_due_reminders()
returns jsonb language plpgsql security definer set search_path=public as $$
declare n_tasks integer;n_capa integer;n_records integer;begin
 insert into public.notifications(user_id,title,body,kind)
 select distinct t.assigned_to,'Nhiệm vụ sắp đến hạn',t.title||' - hạn '||t.due_date::text,'task_due'
 from public.tasks t where t.assigned_to is not null and t.status in('open','in_progress') and t.due_date between current_date and current_date+3
 and not exists(select 1 from public.notifications n where n.user_id=t.assigned_to and n.kind='task_due' and n.body like t.title||'%' and n.created_at::date=current_date);
 get diagnostics n_tasks=row_count;
 insert into public.notifications(user_id,title,body,kind)
 select distinct a.responsible_id,'CAPA quá hạn',a.description||' - hạn '||a.due_date::text,'capa_overdue'
 from public.capa_actions a where a.status in('open','in_progress') and a.due_date<current_date
 and not exists(select 1 from public.notifications n where n.user_id=a.responsible_id and n.kind='capa_overdue' and n.body like a.description||'%' and n.created_at::date=current_date);
 get diagnostics n_capa=row_count;
 select 0 into n_records;
 return jsonb_build_object('task_reminders',n_tasks,'capa_reminders',n_capa,'record_reminders',n_records);
end$$;
revoke all on function public.generate_due_reminders() from public;grant execute on function public.generate_due_reminders() to authenticated;

-- Realtime publication: ignore duplicate membership errors.
do $$ declare t text;begin
 foreach t in array array['criteria','evidence_items','evidence_validations','documents','document_versions','records','nonconformities','capa_actions','form_submissions','tasks','notifications'] loop
  if to_regclass('public.'||t) is not null and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
   begin execute format('alter publication supabase_realtime add table public.%I',t); exception when others then null; end;
  end if;
 end loop;
end $$;

commit;
