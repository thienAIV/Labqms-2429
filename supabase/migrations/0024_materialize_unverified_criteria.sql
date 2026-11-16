-- Materialize the 169 staged criterion structures for UI visibility without legal verification or scoring.
-- Creates clearly provisional evidence requirements. Nothing created here can satisfy official scoring.
begin;

-- Add staged criteria to the operational catalog as unverified placeholders.
insert into public.criteria(
  chapter_id,code,sequence_number,legal_text,max_score,verification_status,
  source_url,source_version,source_document,legal_data_version,verification_note,
  mandatory_level,partial_allowed,source_page,legal_source_id,imported_by,imported_at
)
select
  r.chapter_id,r.normalized_code,r.sequence_number,r.legal_text,r.max_score,'unverified',
  'PDF QD-2429-QD-BYT-2017.pdf','2017-06-12','Quyết định 2429/QĐ-BYT','QD2429-2017-v1',
  'Cấu trúc đã nhập; nguyên văn và yêu cầu bằng chứng đang chờ đối chiếu pháp lý.',
  r.mandatory_level,r.partial_allowed,r.source_page,b.legal_source_id,b.imported_by,now()
from public.legal_import_rows r
join public.legal_import_batches b on b.id=r.batch_id
where b.batch_version='QD2429-2017-v1'
  and not exists(select 1 from public.criteria c where c.code=r.normalized_code);

-- Create two provisional requirements for workflow visibility. They are explicitly unverified,
-- so rules/scoring cannot treat them as official mandatory evidence requirements.
insert into public.evidence_requirements(
  criterion_id,evidence_type_id,title,description,mandatory,minimum_items,
  requires_signature,requires_approval,verification_status,source_url
)
select c.id,et.id,
  case et.category when 'controlled_document' then 'Tài liệu cần bổ sung - chờ xác minh' else 'Hồ sơ cần bổ sung - chờ xác minh' end,
  'Yêu cầu tạm để tiếp nhận và phân loại bằng chứng. Không được dùng làm yêu cầu pháp lý hoặc tính điểm trước khi quản trị viên xác minh theo phụ lục Quyết định 2429/QĐ-BYT.',
  false,0,false,true,'unverified',c.source_url
from public.criteria c
cross join public.evidence_types et
where c.legal_data_version='QD2429-2017-v1'
  and c.verification_status='unverified'
  and et.category in('controlled_document','quality_record')
  and not exists(
    select 1 from public.evidence_requirements er
    where er.criterion_id=c.id and er.evidence_type_id=et.id
  );

-- Dashboard counts all imported criteria, but still labels only verified criteria as verified.
create or replace view public.chapter_quality_dashboard with(security_invoker=true) as
select ch.id chapter_id,ch.roman,ch.name,
 count(distinct c.id) criteria_total,
 count(distinct c.id) filter(where c.verification_status='verified') criteria_verified,
 count(distinct cd.criterion_id) criteria_with_documents,
 count(distinct cr.criterion_id) criteria_with_records,
 count(distinct c.id) filter(where c.verification_status='verified' and cd.criterion_id is null) missing_documents,
 count(distinct c.id) filter(where c.verification_status='verified' and cr.criterion_id is null) missing_records
from public.chapters ch
left join public.criteria c on c.chapter_id=ch.id and c.deleted_at is null
left join public.criterion_documents cd on cd.criterion_id=c.id
left join public.criterion_records cr on cr.criterion_id=c.id
group by ch.id,ch.roman,ch.name;
grant select on public.chapter_quality_dashboard to authenticated;

notify pgrst,'reload schema';
commit;
