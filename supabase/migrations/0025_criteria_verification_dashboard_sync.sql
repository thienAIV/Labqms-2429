-- Safe criterion verification RPC and dashboard synchronization.
begin;

create or replace function public.verify_criterion(
  target_criterion uuid,
  target_source_url text,
  target_source_page integer,
  target_note text
) returns void
language plpgsql
security definer
set search_path=public
as $$
declare c public.criteria;begin
  if not public.is_lab_admin() then raise exception 'FORBIDDEN';end if;
  if target_source_url is null or length(btrim(target_source_url))<5 then raise exception 'SOURCE_REQUIRED';end if;
  if target_source_page is null or target_source_page<1 then raise exception 'SOURCE_PAGE_REQUIRED';end if;
  if target_note is null or length(btrim(target_note))<3 then raise exception 'VERIFICATION_NOTE_REQUIRED';end if;
  select * into c from public.criteria where id=target_criterion for update;
  if c.id is null then raise exception 'CRITERION_NOT_FOUND';end if;
  update public.criteria set
    source_url=target_source_url,
    source_page=target_source_page,
    verified_by=auth.uid(),
    verified_at=now(),
    verification_note=target_note,
    verification_status='verified',
    updated_at=now()
  where id=c.id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'criterion_verified','criterion',c.id::text,jsonb_build_object('code',c.code,'chapter_id',c.chapter_id,'source_page',target_source_page));
end$$;
revoke all on function public.verify_criterion(uuid,text,integer,text) from public;
grant execute on function public.verify_criterion(uuid,text,integer,text) to authenticated;

create or replace view public.chapter_quality_dashboard with(security_invoker=true) as
select ch.id chapter_id,ch.roman,ch.name,
 count(distinct c.id) criteria_total,
 count(distinct c.id) filter(where c.verification_status='verified') criteria_verified,
 count(distinct c.id) filter(where c.verification_status<>'verified') criteria_unverified,
 count(distinct e.criterion_id) filter(where et.category='controlled_document' and e.status='approved') criteria_with_documents,
 count(distinct e.criterion_id) filter(where et.category='quality_record' and e.status='approved') criteria_with_records,
 count(distinct c.id) filter(where c.verification_status='verified' and not exists(
   select 1 from public.evidence_requirements er join public.evidence_types x on x.id=er.evidence_type_id
   join public.evidence_items ei on ei.requirement_id=er.id and ei.status='approved'
   where er.criterion_id=c.id and x.category='controlled_document')) missing_documents,
 count(distinct c.id) filter(where c.verification_status='verified' and not exists(
   select 1 from public.evidence_requirements er join public.evidence_types x on x.id=er.evidence_type_id
   join public.evidence_items ei on ei.requirement_id=er.id and ei.status='approved'
   where er.criterion_id=c.id and x.category='quality_record')) missing_records
from public.chapters ch
left join public.criteria c on c.chapter_id=ch.id and c.deleted_at is null
left join public.evidence_items e on e.criterion_id=c.id and e.deleted_at is null
left join public.evidence_types et on et.id=e.evidence_type_id
group by ch.id,ch.roman,ch.name;
grant select on public.chapter_quality_dashboard to authenticated;
notify pgrst,'reload schema';
commit;
