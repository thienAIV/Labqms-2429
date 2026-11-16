-- QD 2429 protected legal-data import workflow.
-- Requires 0019. This migration does not fabricate or auto-verify criterion text.
begin;

create table if not exists public.legal_import_batches(
 id uuid primary key default gen_random_uuid(),
 legal_source_id uuid not null references public.legal_sources(id) on delete restrict,
 batch_version text not null,
 status text not null default 'draft' check(status in('draft','imported','structure_valid','double_check','approved','rejected')),
 expected_chapters integer not null default 12,
 expected_criteria integer not null default 169,
 expected_max_score numeric not null default 268,
 imported_by uuid not null references public.profiles(id),
 imported_at timestamptz not null default now(),
 checked_by uuid references public.profiles(id),checked_at timestamptz,
 approved_by uuid references public.profiles(id),approved_at timestamptz,
 notes text,unique(legal_source_id,batch_version)
);

create table if not exists public.legal_import_rows(
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.legal_import_batches(id) on delete cascade,
 chapter_id smallint not null check(chapter_id between 1 and 12),source_code text not null,normalized_code text not null,
 sequence_number integer not null,criterion_group text,legal_text text not null,max_score numeric not null check(max_score>0),
 mandatory_level text not null default 'none' check(mandatory_level in('none','level_1','level_3')),
 partial_allowed boolean not null default false,source_page integer not null check(source_page>0),
 source_excerpt_hash text not null check(source_excerpt_hash~'^[a-f0-9]{64}$'),
 row_status text not null default 'in_review' check(row_status in('in_review','checked','needs_revision','approved')),
 reviewer_note text,created_at timestamptz not null default now(),
 unique(batch_id,normalized_code)
);

create table if not exists public.chapter_legal_expectations(
 chapter_id smallint primary key references public.chapters(id),criterion_count integer not null,max_score numeric not null
);
insert into public.chapter_legal_expectations(chapter_id,criterion_count,max_score) values
(1,15,23),(2,8,10),(3,17,21),(4,10,13),(5,19,30),(6,9,13),(7,17,23),(8,27,57),(9,6,11),(10,6,14),(11,8,21),(12,27,32)
on conflict(chapter_id) do update set criterion_count=excluded.criterion_count,max_score=excluded.max_score;

create index if not exists legal_import_rows_batch_idx on public.legal_import_rows(batch_id,chapter_id,sequence_number);
alter table public.legal_import_batches enable row level security;alter table public.legal_import_rows enable row level security;alter table public.chapter_legal_expectations enable row level security;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='legal_import_batches' and policyname='legal_import_batches_admin') then create policy legal_import_batches_admin on public.legal_import_batches for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='legal_import_rows' and policyname='legal_import_rows_admin') then create policy legal_import_rows_admin on public.legal_import_rows for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='chapter_legal_expectations' and policyname='chapter_legal_expectations_read') then create policy chapter_legal_expectations_read on public.chapter_legal_expectations for select to authenticated using(public.is_approved_user());end if;
end $$;

create or replace function public.validate_legal_import_batch(target_batch uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c integer;s numeric;ch integer;duplicate_codes integer;bad_chapters integer;begin
 if not public.is_lab_admin() then raise exception 'FORBIDDEN';end if;
 select count(*),coalesce(sum(max_score),0),count(distinct chapter_id) into c,s,ch from public.legal_import_rows where batch_id=target_batch;
 select count(*)-count(distinct normalized_code) into duplicate_codes from public.legal_import_rows where batch_id=target_batch;
 select count(*) into bad_chapters from(
  select e.chapter_id,e.criterion_count,e.max_score,count(r.id) actual_count,coalesce(sum(r.max_score),0) actual_score
  from public.chapter_legal_expectations e left join public.legal_import_rows r on r.batch_id=target_batch and r.chapter_id=e.chapter_id
  group by e.chapter_id,e.criterion_count,e.max_score
  having count(r.id)<>e.criterion_count or coalesce(sum(r.max_score),0)<>e.max_score
 )x;
 if c<>169 then raise exception 'EXPECTED_169_CRITERIA_GOT_%',c;end if;
 if s<>268 then raise exception 'EXPECTED_268_POINTS_GOT_%',s;end if;
 if ch<>12 then raise exception 'EXPECTED_12_CHAPTERS_GOT_%',ch;end if;
 if duplicate_codes>0 then raise exception 'DUPLICATE_NORMALIZED_CODES_%',duplicate_codes;end if;
 if bad_chapters>0 then raise exception 'CHAPTER_TOTAL_MISMATCH_%',bad_chapters;end if;
 if exists(select 1 from public.legal_import_rows where batch_id=target_batch and(length(trim(legal_text))<10 or source_page<1 or source_excerpt_hash is null)) then raise exception 'INCOMPLETE_SOURCE_TRACE';end if;
 update public.legal_import_batches set status='structure_valid',checked_by=auth.uid(),checked_at=now() where id=target_batch;
 return jsonb_build_object('chapters',ch,'criteria',c,'max_score',s,'chapter_totals','valid','status','structure_valid');
end$$;

create or replace function public.approve_legal_import_batch(target_batch uuid,target_note text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare b public.legal_import_batches;v jsonb;begin
 if not exists(select 1 from public.profiles where id=auth.uid() and status='approved' and role='super_admin') then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 v:=public.validate_legal_import_batch(target_batch);select * into b from public.legal_import_batches where id=target_batch for update;
 if exists(select 1 from public.legal_import_rows where batch_id=target_batch and row_status<>'approved') then raise exception 'DOUBLE_CHECK_NOT_COMPLETE';end if;
 insert into public.criteria(chapter_id,code,sequence_number,criterion_group,legal_text,max_score,verification_status,source_url,source_version,source_document,legal_data_version,verified_by,verified_at,verification_note,mandatory_level,partial_allowed,source_page,legal_source_id)
 select r.chapter_id,r.normalized_code,r.sequence_number,r.criterion_group,r.legal_text,r.max_score,'verified',
 'PDF QD-2429-QD-BYT-2017.pdf','2017-06-12','Quyết định 2429/QĐ-BYT','QD2429-2017-v1',auth.uid(),now(),target_note,r.mandatory_level,r.partial_allowed,r.source_page,b.legal_source_id
 from public.legal_import_rows r where r.batch_id=target_batch
 on conflict do nothing;
 insert into public.criterion_versions(criterion_id,legal_source_id,version_number,code,chapter_id,sequence_number,legal_text,max_score,mandatory_level,partial_allowed,source_page,source_excerpt_hash,status,imported_by,verified_by,verified_at,verification_note)
 select c.id,b.legal_source_id,1,r.normalized_code,r.chapter_id,r.sequence_number,r.legal_text,r.max_score,r.mandatory_level,r.partial_allowed,r.source_page,r.source_excerpt_hash,'verified',b.imported_by,auth.uid(),now(),target_note
 from public.legal_import_rows r join public.criteria c on c.code=r.normalized_code where r.batch_id=target_batch
 on conflict(criterion_id,version_number) do nothing;
 update public.legal_import_batches set status='approved',approved_by=auth.uid(),approved_at=now(),notes=target_note where id=target_batch;
 update public.legal_sources set status='verified',verified_by=auth.uid(),verified_at=now() where id=b.legal_source_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,details) values(auth.uid(),'legal_dataset_approved','legal_import_batch',target_batch::text,v);
 return v||jsonb_build_object('status','approved');
end$$;

revoke all on function public.validate_legal_import_batch(uuid),public.approve_legal_import_batch(uuid,text) from public;
grant execute on function public.validate_legal_import_batch(uuid),public.approve_legal_import_batch(uuid,text) to authenticated;

create or replace view public.legal_import_progress with(security_invoker=true) as
select b.id,b.batch_version,b.status,count(r.id) rows_total,count(r.id) filter(where r.row_status='approved') rows_approved,
 count(distinct r.chapter_id) chapters,coalesce(sum(r.max_score),0) max_score
from public.legal_import_batches b left join public.legal_import_rows r on r.batch_id=b.id group by b.id,b.batch_version,b.status;
grant select on public.legal_import_progress to authenticated;

insert into public.legal_sources(document_number,issued_date,issuer,title,source_file_name,source_sha256,page_count,expected_chapters,expected_criteria,expected_max_score,status,notes)
values('2429/QĐ-BYT','2017-06-12','Bộ Y tế','Tiêu chí đánh giá mức chất lượng phòng xét nghiệm y học','QD-2429-QD-BYT-2017.pdf','845139f4673a8d6e88cabd00cf572d7f80060aceb400dd26a99b932ace2f9be6',41,12,169,268,'extracting','Đang trích xuất và đối chiếu kép 169 tiêu chí; chưa dùng để tính điểm chính thức.')
on conflict(source_sha256) do update set status=case when public.legal_sources.status='verified' then 'verified' else 'extracting' end,notes=excluded.notes;

commit;
