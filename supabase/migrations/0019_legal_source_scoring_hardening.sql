-- Official source registry and legal scoring hardening for QD 2429/QD-BYT.
-- This migration does not OCR or silently alter legal criterion text.
begin;

create table if not exists public.legal_sources(
 id uuid primary key default gen_random_uuid(),document_number text not null,issued_date date not null,
 issuer text not null,title text not null,source_file_name text not null,source_sha256 text not null unique check(source_sha256~'^[a-f0-9]{64}$'),
 page_count integer not null check(page_count>0),expected_chapters integer not null,expected_criteria integer not null,
 expected_max_score numeric not null,status text not null default 'received' check(status in('received','extracting','in_review','verified','rejected','superseded')),
 verified_by uuid references public.profiles(id),verified_at timestamptz,notes text,created_at timestamptz not null default now(),
 check(status<>'verified' or(verified_by is not null and verified_at is not null))
);

create table if not exists public.criterion_versions(
 id uuid primary key default gen_random_uuid(),criterion_id uuid not null references public.criteria(id) on delete restrict,
 legal_source_id uuid not null references public.legal_sources(id),version_number integer not null check(version_number>0),
 code text not null,chapter_id smallint not null references public.chapters(id),sequence_number integer not null,
 legal_text text not null,max_score numeric not null check(max_score>0),mandatory_level text not null default 'none' check(mandatory_level in('none','level_1','level_3')),
 partial_allowed boolean not null default false,subitem_count integer not null default 0 check(subitem_count>=0),
 source_page integer not null check(source_page>0),source_excerpt_hash text not null check(source_excerpt_hash~'^[a-f0-9]{64}$'),
 status text not null default 'in_review' check(status in('in_review','verified','needs_revision','retired')),
 imported_by uuid references public.profiles(id),imported_at timestamptz not null default now(),verified_by uuid references public.profiles(id),verified_at timestamptz,verification_note text,
 unique(criterion_id,version_number),unique(legal_source_id,code,version_number),
 check(status<>'verified' or(verified_by is not null and verified_at is not null))
);

create table if not exists public.criterion_subitems(
 id uuid primary key default gen_random_uuid(),criterion_version_id uuid not null references public.criterion_versions(id) on delete cascade,
 item_key text not null,item_text text not null,sort_order integer not null,source_page integer not null,
 unique(criterion_version_id,item_key)
);

alter table public.criteria add column if not exists mandatory_level text not null default 'none';
alter table public.criteria add column if not exists partial_allowed boolean not null default false;
alter table public.criteria add column if not exists source_page integer;
alter table public.criteria add column if not exists legal_source_id uuid references public.legal_sources(id);

do $$ begin
 if not exists(select 1 from pg_constraint where conname='criteria_mandatory_level_check') then
  alter table public.criteria add constraint criteria_mandatory_level_check check(mandatory_level in('none','level_1','level_3')) not valid;
  alter table public.criteria validate constraint criteria_mandatory_level_check;
 end if;
end $$;

create index if not exists criterion_versions_source_idx on public.criterion_versions(legal_source_id,chapter_id,sequence_number);
create index if not exists criterion_subitems_version_idx on public.criterion_subitems(criterion_version_id,sort_order);
alter table public.legal_sources enable row level security;alter table public.criterion_versions enable row level security;alter table public.criterion_subitems enable row level security;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='legal_sources' and policyname='legal_sources_read') then create policy legal_sources_read on public.legal_sources for select to authenticated using(public.is_approved_user());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='legal_sources' and policyname='legal_sources_admin') then create policy legal_sources_admin on public.legal_sources for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_versions' and policyname='criterion_versions_read') then create policy criterion_versions_read on public.criterion_versions for select to authenticated using(public.is_approved_user());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_versions' and policyname='criterion_versions_admin') then create policy criterion_versions_admin on public.criterion_versions for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_subitems' and policyname='criterion_subitems_read') then create policy criterion_subitems_read on public.criterion_subitems for select to authenticated using(public.is_approved_user());end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_subitems' and policyname='criterion_subitems_admin') then create policy criterion_subitems_admin on public.criterion_subitems for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());end if;
end $$;

create or replace function public.calculate_criterion_score(target_criterion uuid,target_result text,target_achieved_subitems integer default null) returns numeric language plpgsql stable security definer set search_path=public as $$
declare c public.criteria;total_subitems integer;begin
 select * into c from public.criteria where id=target_criterion;
 if c.id is null then raise exception 'CRITERION_NOT_FOUND';end if;
 if c.verification_status<>'verified' then raise exception 'CRITERION_NOT_VERIFIED';end if;
 if c.max_score is null then raise exception 'MAX_SCORE_NOT_CONFIGURED';end if;
 if target_result='achieved' then return c.max_score;
 elsif target_result='not_achieved' then return 0;
 elsif target_result='partial' then
  if not c.partial_allowed then raise exception 'PARTIAL_NOT_ALLOWED';end if;
  select count(*) into total_subitems from public.criterion_subitems s join public.criterion_versions v on v.id=s.criterion_version_id where v.criterion_id=c.id and v.status='verified';
  if total_subitems=0 or target_achieved_subitems is null then raise exception 'SUBITEM_RESULT_REQUIRED';end if;
  if target_achieved_subitems*2<total_subitems then return 0;end if;
  return c.max_score/2;
 elsif target_result='not_applicable' then return null;
 else raise exception 'INVALID_ASSESSMENT_RESULT';end if;
end$$;
revoke all on function public.calculate_criterion_score(uuid,text,integer) from public;grant execute on function public.calculate_criterion_score(uuid,text,integer) to authenticated;

create or replace function public.classify_2429_quality(target_assessment uuid) returns text language plpgsql stable security definer set search_path=public as $$
declare pct numeric;mandatory_one_ok boolean;mandatory_three_ok boolean;begin
 if not exists(select 1 from public.assessments a where a.id=target_assessment and a.status in('approved','closed')) then raise exception 'ASSESSMENT_NOT_APPROVED';end if;
 if exists(select 1 from public.assessment_items i join public.criteria c on c.id=i.criterion_id where i.assessment_id=target_assessment and(c.verification_status<>'verified' or i.status='not_assessed')) then raise exception 'ASSESSMENT_INCOMPLETE_OR_UNVERIFIED';end if;
 select 100*coalesce(sum(i.score),0)/nullif(sum(c.max_score) filter(where i.status<>'not_applicable'),0) into pct from public.assessment_items i join public.criteria c on c.id=i.criterion_id where i.assessment_id=target_assessment;
 select not exists(select 1 from public.assessment_items i join public.criteria c on c.id=i.criterion_id where i.assessment_id=target_assessment and c.mandatory_level='level_1' and i.score<c.max_score) into mandatory_one_ok;
 select not exists(select 1 from public.assessment_items i join public.criteria c on c.id=i.criterion_id where i.assessment_id=target_assessment and c.mandatory_level='level_3' and i.score<c.max_score) into mandatory_three_ok;
 if pct<20 or not mandatory_one_ok then return 'Chưa xếp mức';elsif pct<35 then return 'Mức 1';elsif pct<65 then return 'Mức 2';elsif pct<85 and mandatory_three_ok then return 'Mức 3';elsif pct<95 and mandatory_three_ok then return 'Mức 4';elsif pct>=95 and mandatory_three_ok then return 'Mức 5';else return 'Chưa xếp mức';end if;
end$$;
revoke all on function public.classify_2429_quality(uuid) from public;grant execute on function public.classify_2429_quality(uuid) to authenticated;

create or replace function public.verify_2429_dataset(target_source uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare n_chapters integer;n_criteria integer;n_score numeric;bad_codes integer;begin
 if not public.is_lab_admin() then raise exception 'FORBIDDEN';end if;
 select count(distinct chapter_id),count(*),sum(max_score),count(*) filter(where code is null or legal_text is null or source_page is null) into n_chapters,n_criteria,n_score,bad_codes from public.criterion_versions where legal_source_id=target_source and status in('in_review','verified');
 if n_chapters<>12 then raise exception 'EXPECTED_12_CHAPTERS_GOT_%',n_chapters;end if;
 if n_criteria<>169 then raise exception 'EXPECTED_169_CRITERIA_GOT_%',n_criteria;end if;
 if n_score<>268 then raise exception 'EXPECTED_268_POINTS_GOT_%',n_score;end if;
 if bad_codes>0 then raise exception 'INCOMPLETE_LEGAL_ROWS_%',bad_codes;end if;
 return jsonb_build_object('chapters',n_chapters,'criteria',n_criteria,'max_score',n_score,'status','structure_valid');
end$$;
revoke all on function public.verify_2429_dataset(uuid) from public;grant execute on function public.verify_2429_dataset(uuid) to authenticated;

insert into public.legal_sources(document_number,issued_date,issuer,title,source_file_name,source_sha256,page_count,expected_chapters,expected_criteria,expected_max_score,status,notes)
values('2429/QĐ-BYT','2017-06-12','Bộ Y tế','Tiêu chí đánh giá mức chất lượng phòng xét nghiệm y học','QD-2429-QD-BYT-2017.pdf','845139f4673a8d6e88cabd00cf572d7f80060aceb400dd26a99b932ace2f9be6',41,12,169,268,'received','PDF toàn văn do người dùng cung cấp; cần đối chiếu kép dữ liệu trích xuất trước khi chuyển verified.')
on conflict(source_sha256) do update set source_file_name=excluded.source_file_name,page_count=excluded.page_count,notes=excluded.notes;

commit;
