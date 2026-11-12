begin;

create or replace function public.write_critical_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_action text;
  v_entity_id text;
  v_details jsonb := '{}'::jsonb;
begin
  v_action := tg_table_name || case tg_op when 'INSERT' then '_created' when 'UPDATE' then '_updated' when 'DELETE' then '_deleted' end;
  v_entity_id := case when tg_op='DELETE' then old.id::text else new.id::text end;
  if v_actor is null then
    if tg_table_name='nonconformities' and tg_op<>'DELETE' then v_actor:=new.reported_by;
    elsif tg_table_name='documents' and tg_op<>'DELETE' then v_actor:=new.owner_id;
    elsif tg_table_name='document_versions' and tg_op<>'DELETE' then v_actor:=new.created_by;
    elsif tg_table_name='capa_actions' and tg_op<>'DELETE' then v_actor:=new.responsible_id;
    elsif tg_table_name='document_reviews' and tg_op<>'DELETE' then v_actor:=new.reviewer_id;
    elsif tg_table_name='document_approvals' and tg_op<>'DELETE' then v_actor:=new.approver_id;
    end if;
  end if;
  if tg_table_name='nonconformities' then
    if tg_op='DELETE' then v_details:=jsonb_build_object('code',old.code,'status',old.status,'severity',old.severity);
    else v_details:=jsonb_build_object('code',new.code,'status',new.status,'severity',new.severity); end if;
  elsif tg_table_name='documents' then
    if tg_op='DELETE' then v_details:=jsonb_build_object('code',old.code,'current_version',old.current_version);
    else v_details:=jsonb_build_object('code',new.code,'current_version',new.current_version); end if;
  elsif tg_table_name='document_versions' then
    if tg_op='DELETE' then v_details:=jsonb_build_object('document_id',old.document_id,'version_number',old.version_number,'status',old.status);
    else v_details:=jsonb_build_object('document_id',new.document_id,'version_number',new.version_number,'status',new.status); end if;
  elsif tg_table_name='capa_actions' then
    if tg_op='DELETE' then v_details:=jsonb_build_object('nonconformity_id',old.nonconformity_id,'action_type',old.action_type,'status',old.status);
    else v_details:=jsonb_build_object('nonconformity_id',new.nonconformity_id,'action_type',new.action_type,'status',new.status); end if;
  elsif tg_table_name='document_reviews' then
    v_details:=jsonb_build_object('document_version_id',new.document_version_id,'decision',new.decision);
  elsif tg_table_name='document_approvals' then
    v_details:=jsonb_build_object('document_version_id',new.document_version_id,'decision',new.decision);
  end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details)
  values(v_actor,v_action,tg_table_name,v_entity_id,v_details);
  return coalesce(new,old);
end;
$$;
revoke all on function public.write_critical_audit_event() from public,anon,authenticated;

do $$ begin
  drop trigger if exists trg_audit_nonconformities on public.nonconformities;
  create trigger trg_audit_nonconformities after insert or update or delete on public.nonconformities for each row execute function public.write_critical_audit_event();
  drop trigger if exists trg_audit_documents on public.documents;
  create trigger trg_audit_documents after insert or update or delete on public.documents for each row execute function public.write_critical_audit_event();
  drop trigger if exists trg_audit_document_versions on public.document_versions;
  create trigger trg_audit_document_versions after insert or update or delete on public.document_versions for each row execute function public.write_critical_audit_event();
  drop trigger if exists trg_audit_capa_actions on public.capa_actions;
  create trigger trg_audit_capa_actions after insert or update or delete on public.capa_actions for each row execute function public.write_critical_audit_event();
  drop trigger if exists trg_audit_document_reviews on public.document_reviews;
  create trigger trg_audit_document_reviews after insert or update or delete on public.document_reviews for each row execute function public.write_critical_audit_event();
  drop trigger if exists trg_audit_document_approvals on public.document_approvals;
  create trigger trg_audit_document_approvals after insert or update or delete on public.document_approvals for each row execute function public.write_critical_audit_event();
end $$;

insert into public.audit_logs(actor_id,action,entity_type,entity_id,details,created_at)
select n.reported_by,'nonconformities_created_backfill','nonconformities',n.id::text,
 jsonb_build_object('code',n.code,'status',n.status,'severity',n.severity),n.reported_at
from public.nonconformities n
where not exists(select 1 from public.audit_logs a where a.entity_type='nonconformities' and a.entity_id=n.id::text);

commit;
