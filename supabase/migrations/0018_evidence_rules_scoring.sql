-- LabQMS 2429: evidence lifecycle, rules engine, expert review and protected scoring.
-- No legal criterion text or official score is seeded by this migration.
begin;

alter table public.criteria add column if not exists criterion_group text;
alter table public.criteria add column if not exists score_condition text;
alter table public.criteria add column if not exists assessment_method text;
alter table public.criteria add column if not exists verification_note text;
alter table public.criteria add column if not exists imported_by uuid references public.profiles(id);
alter table public.criteria add column if not exists imported_at timestamptz;
alter table public.criteria add column if not exists deleted_at timestamptz;

create table if not exists public.evidence_types(
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
 category text not null check(category in('controlled_document','quality_record','observation','interview')),
 allows_file boolean not null default true, requires_structured_form boolean not null default false,
 active boolean not null default true, created_at timestamptz not null default now()
);
insert into public.evidence_types(code,name,category,allows_file,requires_structured_form) values
 ('CONTROLLED_DOCUMENT','Tài liệu được kiểm soát','controlled_document',true,false),
 ('QUALITY_RECORD','Hồ sơ minh chứng','quality_record',true,false),
 ('OBSERVATION','Bằng chứng quan sát','observation',true,true),
 ('INTERVIEW','Bằng chứng phỏng vấn','interview',false,true)
on conflict(code) do update set name=excluded.name,active=true;

create table if not exists public.evidence_requirements(
 id uuid primary key default gen_random_uuid(), criterion_id uuid not null references public.criteria(id) on delete cascade,
 evidence_type_id uuid not null references public.evidence_types(id), title text not null, description text not null,
 mandatory boolean not null default true, minimum_items integer not null default 1 check(minimum_items>=0),
 frequency text, validity_days integer check(validity_days is null or validity_days>0),
 requires_signature boolean not null default false, requires_approval boolean not null default true,
 verification_status text not null default 'unverified' check(verification_status in('unverified','in_review','verified','needs_revision','retired')),
 source_url text, verified_by uuid references public.profiles(id), verified_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(verification_status<>'verified' or(source_url is not null and verified_by is not null and verified_at is not null))
);

create table if not exists public.evidence_items(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 laboratory_id uuid not null references public.laboratories(id), chapter_id smallint not null references public.chapters(id),
 criterion_id uuid not null references public.criteria(id), requirement_id uuid not null references public.evidence_requirements(id),
 evidence_type_id uuid not null references public.evidence_types(id), title text not null, description text,
 period_start date, period_end date, performed_at timestamptz, owner_id uuid not null references public.profiles(id),
 reviewer_id uuid references public.profiles(id), approver_id uuid references public.profiles(id),
 status text not null default 'unchecked' check(status in('unchecked','automatic_check','technical_failed','metadata_missing','wrong_type','wrong_criterion','wrong_period','ai_review','expert_review','needs_supplement','rejected','verified','approved','expired','superseded','withdrawn')),
 valid_from date, valid_until date, approved_at timestamptz, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), deleted_at timestamptz,
 check(period_end is null or period_start is not null and period_end>=period_start)
);
create table if not exists public.evidence_files(
 id uuid primary key default gen_random_uuid(), evidence_id uuid not null references public.evidence_items(id) on delete restrict,
 storage_path text not null unique, file_name text not null, mime_type text not null, file_extension text not null,
 file_size bigint not null check(file_size>0 and file_size<=52428800), checksum_sha256 text not null check(checksum_sha256~'^[a-f0-9]{64}$'),
 technical_status text not null default 'unchecked' check(technical_status in('unchecked','pass','fail','quarantined')),
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), unique(evidence_id,checksum_sha256)
);
create table if not exists public.observation_evidence(
 evidence_id uuid primary key references public.evidence_items(id) on delete cascade, area text not null,
 observed_object text not null, evaluator_id uuid not null references public.profiles(id), observed_at timestamptz not null,
 content text not null, result text not null, comment text, action_required text, confirmed_at timestamptz
);
create table if not exists public.interview_evidence(
 evidence_id uuid primary key references public.evidence_items(id) on delete cascade, interviewee_role text not null,
 evaluator_id uuid not null references public.profiles(id), interviewed_at timestamptz not null, topic text not null,
 questions jsonb not null, result text not null, comment text, improvement_points text, confirmed_at timestamptz
);
create table if not exists public.validation_rules(
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
 scope text not null check(scope in('file','metadata','lifecycle','period','content','signature','linkage')),
 severity text not null check(severity in('error','warning','info')), active boolean not null default true,
 configuration jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.evidence_validations(
 id uuid primary key default gen_random_uuid(), evidence_id uuid not null references public.evidence_items(id) on delete cascade,
 run_id uuid not null, rule_id uuid not null references public.validation_rules(id),
 result text not null check(result in('PASS','FAIL','WARNING','NOT_APPLICABLE','NEEDS_HUMAN_REVIEW')),
 message text not null, details jsonb not null default '{}'::jsonb, evaluated_at timestamptz not null default now(),
 unique(run_id,rule_id)
);
create table if not exists public.expert_reviews(
 id uuid primary key default gen_random_uuid(), evidence_id uuid not null references public.evidence_items(id) on delete restrict,
 reviewer_id uuid not null references public.profiles(id), decision text not null check(decision in('approved','rejected','needs_supplement')),
 comment text not null, reviewed_at timestamptz not null default now(), unique(evidence_id,reviewer_id)
);
create table if not exists public.assessment_rounds(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 laboratory_id uuid not null references public.laboratories(id), title text not null, period_start date not null, period_end date not null,
 status text not null default 'draft' check(status in('draft','self_assessment','expert_review','approval','closed','reassessment_required')),
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), check(period_end>=period_start)
);
create table if not exists public.score_proposals(
 id uuid primary key default gen_random_uuid(), assessment_round_id uuid not null references public.assessment_rounds(id) on delete cascade,
 criterion_id uuid not null references public.criteria(id), self_score numeric, self_comment text,
 automatic_score numeric, automatic_reason text, proposed_at timestamptz, unique(assessment_round_id,criterion_id)
);
create table if not exists public.score_approvals(
 id uuid primary key default gen_random_uuid(), score_proposal_id uuid not null unique references public.score_proposals(id) on delete restrict,
 approved_score numeric not null, approved_by uuid not null references public.profiles(id), approved_at timestamptz not null default now(),
 comment text not null
);

create index if not exists evidence_requirements_criterion_idx on public.evidence_requirements(criterion_id,verification_status);
create index if not exists evidence_items_scope_idx on public.evidence_items(organization_id,laboratory_id,chapter_id,criterion_id,status);
create index if not exists evidence_validations_evidence_idx on public.evidence_validations(evidence_id,evaluated_at desc);
create index if not exists score_proposals_round_idx on public.score_proposals(assessment_round_id,criterion_id);

alter table public.evidence_types enable row level security; alter table public.evidence_requirements enable row level security;
alter table public.evidence_items enable row level security; alter table public.evidence_files enable row level security;
alter table public.observation_evidence enable row level security; alter table public.interview_evidence enable row level security;
alter table public.validation_rules enable row level security; alter table public.evidence_validations enable row level security;
alter table public.expert_reviews enable row level security; alter table public.assessment_rounds enable row level security;
alter table public.score_proposals enable row level security; alter table public.score_approvals enable row level security;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_types' and policyname='evidence_types_read') then create policy evidence_types_read on public.evidence_types for select to authenticated using(public.is_approved_user()); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_requirements' and policyname='evidence_requirements_read') then create policy evidence_requirements_read on public.evidence_requirements for select to authenticated using(public.is_approved_user()); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_items' and policyname='evidence_items_read') then create policy evidence_items_read on public.evidence_items for select to authenticated using(public.can_read_scope(organization_id,laboratory_id)); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_items' and policyname='evidence_items_insert') then create policy evidence_items_insert on public.evidence_items for insert to authenticated with check(owner_id=auth.uid() and public.can_read_scope(organization_id,laboratory_id) and public.has_permission('create')); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_files' and policyname='evidence_files_read') then create policy evidence_files_read on public.evidence_files for select to authenticated using(exists(select 1 from public.evidence_items e where e.id=evidence_files.evidence_id and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_files' and policyname='evidence_files_insert') then create policy evidence_files_insert on public.evidence_files for insert to authenticated with check(created_by=auth.uid() and exists(select 1 from public.evidence_items e where e.id=evidence_files.evidence_id and e.owner_id=auth.uid() and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='observation_evidence' and policyname='observation_evidence_read') then create policy observation_evidence_read on public.observation_evidence for select to authenticated using(exists(select 1 from public.evidence_items e where e.id=observation_evidence.evidence_id and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='interview_evidence' and policyname='interview_evidence_read') then create policy interview_evidence_read on public.interview_evidence for select to authenticated using(exists(select 1 from public.evidence_items e where e.id=interview_evidence.evidence_id and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='validation_rules' and policyname='validation_rules_read') then create policy validation_rules_read on public.validation_rules for select to authenticated using(public.is_approved_user()); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_validations' and policyname='evidence_validations_read') then create policy evidence_validations_read on public.evidence_validations for select to authenticated using(exists(select 1 from public.evidence_items e where e.id=evidence_validations.evidence_id and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='expert_reviews' and policyname='expert_reviews_read') then create policy expert_reviews_read on public.expert_reviews for select to authenticated using(exists(select 1 from public.evidence_items e where e.id=expert_reviews.evidence_id and public.can_read_scope(e.organization_id,e.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='assessment_rounds' and policyname='assessment_rounds_read') then create policy assessment_rounds_read on public.assessment_rounds for select to authenticated using(public.can_read_scope(organization_id,laboratory_id)); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='score_proposals' and policyname='score_proposals_read') then create policy score_proposals_read on public.score_proposals for select to authenticated using(exists(select 1 from public.assessment_rounds r where r.id=score_proposals.assessment_round_id and public.can_read_scope(r.organization_id,r.laboratory_id))); end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='score_approvals' and policyname='score_approvals_read') then create policy score_approvals_read on public.score_approvals for select to authenticated using(exists(select 1 from public.score_proposals p join public.assessment_rounds r on r.id=p.assessment_round_id where p.id=score_approvals.score_proposal_id and public.can_read_scope(r.organization_id,r.laboratory_id))); end if;
end $$;

insert into public.validation_rules(code,name,scope,severity) values
 ('FILE_EXISTS','File tồn tại','file','error'),('FILE_NONEMPTY','File không rỗng','file','error'),
 ('FILE_ALLOWED_TYPE','Định dạng được phép','file','error'),('METADATA_REQUIRED','Metadata bắt buộc đầy đủ','metadata','error'),
 ('LINK_CORRECT','Liên kết đúng tiêu chí và yêu cầu','linkage','error'),('PERIOD_VALID','Đúng kỳ hồ sơ','period','error'),
 ('LIFECYCLE_VALID','Còn hiệu lực và chưa bị thay thế','lifecycle','error'),
 ('SIGNATURE_REQUIRED','Có xác nhận bắt buộc','signature','error'),
 ('CONTENT_HUMAN_REVIEW','Nội dung cần người có thẩm quyền rà soát','content','warning')
on conflict(code) do update set name=excluded.name,active=true;

create or replace function public.run_evidence_rules(target_evidence uuid) returns uuid language plpgsql security definer set search_path=public,storage as $$
declare e public.evidence_items; f public.evidence_files; r public.evidence_requirements; run uuid:=gen_random_uuid();begin
 select * into e from public.evidence_items where id=target_evidence for update;
 if e.id is null then raise exception 'EVIDENCE_NOT_FOUND'; end if;
 if not public.can_read_scope(e.organization_id,e.laboratory_id) then raise exception 'FORBIDDEN'; end if;
 select * into r from public.evidence_requirements where id=e.requirement_id;
 select * into f from public.evidence_files where evidence_id=e.id order by created_at desc limit 1;
 insert into public.evidence_validations(evidence_id,run_id,rule_id,result,message)
 select e.id,run,vr.id,
 case vr.code
  when 'FILE_EXISTS' then case when et.allows_file=false then 'NOT_APPLICABLE' when f.id is not null and exists(select 1 from storage.objects o where o.bucket_id='documents' and o.name=f.storage_path) then 'PASS' else 'FAIL' end
  when 'FILE_NONEMPTY' then case when et.allows_file=false then 'NOT_APPLICABLE' when f.file_size>0 then 'PASS' else 'FAIL' end
  when 'FILE_ALLOWED_TYPE' then case when et.allows_file=false then 'NOT_APPLICABLE' when f.mime_type in('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv','image/jpeg','image/png') then 'PASS' else 'FAIL' end
  when 'METADATA_REQUIRED' then case when e.title is not null and e.owner_id is not null and e.criterion_id is not null and e.requirement_id is not null then 'PASS' else 'FAIL' end
  when 'LINK_CORRECT' then case when r.criterion_id=e.criterion_id and r.id=e.requirement_id and r.evidence_type_id=e.evidence_type_id then 'PASS' else 'FAIL' end
  when 'PERIOD_VALID' then case when r.frequency is null or(e.period_start is not null and e.period_end is not null and e.period_end>=e.period_start) then 'PASS' else 'FAIL' end
  when 'LIFECYCLE_VALID' then case when e.status not in('expired','superseded','withdrawn','rejected') and(e.valid_until is null or e.valid_until>=current_date) then 'PASS' else 'FAIL' end
  else 'NEEDS_HUMAN_REVIEW' end,
 vr.name from public.validation_rules vr cross join public.evidence_types et where et.id=e.evidence_type_id and vr.active;
 update public.evidence_items set status=case when exists(select 1 from public.evidence_validations where run_id=run and result='FAIL') then 'needs_supplement' else 'expert_review' end,updated_at=now() where id=e.id;
 return run;
end $$;
revoke all on function public.run_evidence_rules(uuid) from public; grant execute on function public.run_evidence_rules(uuid) to authenticated;

create or replace function public.submit_expert_review(target_evidence uuid,target_decision text,target_comment text) returns void language plpgsql security definer set search_path=public as $$
declare e public.evidence_items;begin
 select * into e from public.evidence_items where id=target_evidence for update;
 if e.id is null then raise exception 'EVIDENCE_NOT_FOUND'; end if;
 if e.owner_id=auth.uid() then raise exception 'SEPARATION_OF_DUTIES'; end if;
 if not public.has_permission('approve') then raise exception 'FORBIDDEN'; end if;
 if target_decision not in('approved','rejected','needs_supplement') then raise exception 'INVALID_DECISION'; end if;
 if exists(select 1 from public.evidence_validations where evidence_id=e.id and result='FAIL') and target_decision='approved' then raise exception 'VALIDATION_FAILED'; end if;
 insert into public.expert_reviews(evidence_id,reviewer_id,decision,comment) values(e.id,auth.uid(),target_decision,target_comment) on conflict(evidence_id,reviewer_id) do update set decision=excluded.decision,comment=excluded.comment,reviewed_at=now();
 update public.evidence_items set reviewer_id=auth.uid(),approver_id=case when target_decision='approved' then auth.uid() else approver_id end,status=case target_decision when 'approved' then 'approved' when 'rejected' then 'rejected' else 'needs_supplement' end,approved_at=case when target_decision='approved' then now() else null end,updated_at=now() where id=e.id;
end $$;
revoke all on function public.submit_expert_review(uuid,text,text) from public; grant execute on function public.submit_expert_review(uuid,text,text) to authenticated;

create or replace function public.propose_criterion_score(target_round uuid,target_criterion uuid) returns numeric language plpgsql security definer set search_path=public as $$
declare c public.criteria; score numeric;begin
 select * into c from public.criteria where id=target_criterion;
 if c.verification_status<>'verified' then raise exception 'CRITERION_NOT_VERIFIED'; end if;
 if c.max_score is null or c.score_condition is null then raise exception 'SCORING_NOT_CONFIGURED'; end if;
 if exists(select 1 from public.evidence_requirements r where r.criterion_id=c.id and r.mandatory and r.verification_status='verified' and not exists(select 1 from public.evidence_items e where e.requirement_id=r.id and e.status='approved' and(e.valid_until is null or e.valid_until>=current_date))) then score:=0; else score:=c.max_score; end if;
 insert into public.score_proposals(assessment_round_id,criterion_id,automatic_score,automatic_reason,proposed_at) values(target_round,c.id,score,'Đề xuất rules engine; bắt buộc người có thẩm quyền phê duyệt',now()) on conflict(assessment_round_id,criterion_id) do update set automatic_score=excluded.automatic_score,automatic_reason=excluded.automatic_reason,proposed_at=now();
 return score;
end $$;
revoke all on function public.propose_criterion_score(uuid,uuid) from public; grant execute on function public.propose_criterion_score(uuid,uuid) to authenticated;

create or replace function public.save_self_score(target_round uuid,target_criterion uuid,target_score numeric,target_comment text) returns void language plpgsql security definer set search_path=public as $$
declare c public.criteria;r public.assessment_rounds;begin
 select * into c from public.criteria where id=target_criterion;select * into r from public.assessment_rounds where id=target_round;
 if c.verification_status<>'verified' then raise exception 'CRITERION_NOT_VERIFIED';end if;
 if target_comment is null or length(trim(target_comment))=0 then raise exception 'COMMENT_REQUIRED';end if;
 if target_score<0 or c.max_score is null or target_score>c.max_score then raise exception 'INVALID_SCORE';end if;
 if not public.can_read_scope(r.organization_id,r.laboratory_id) or not public.has_permission('update') then raise exception 'FORBIDDEN';end if;
 insert into public.score_proposals(assessment_round_id,criterion_id,self_score,self_comment) values(target_round,target_criterion,target_score,target_comment)
 on conflict(assessment_round_id,criterion_id) do update set self_score=excluded.self_score,self_comment=excluded.self_comment;
end$$;
create or replace function public.approve_score_proposal(target_proposal uuid,target_score numeric,target_comment text) returns void language plpgsql security definer set search_path=public as $$
declare p public.score_proposals;c public.criteria;begin
 if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;
 select * into p from public.score_proposals where id=target_proposal;select c.* into c from public.criteria c where c.id=p.criterion_id;
 if c.verification_status<>'verified' then raise exception 'CRITERION_NOT_VERIFIED';end if;
 if target_score<0 or c.max_score is null or target_score>c.max_score then raise exception 'INVALID_SCORE';end if;
 if target_comment is null or length(trim(target_comment))=0 then raise exception 'COMMENT_REQUIRED';end if;
 insert into public.score_approvals(score_proposal_id,approved_score,approved_by,comment) values(p.id,target_score,auth.uid(),target_comment)
 on conflict(score_proposal_id) do update set approved_score=excluded.approved_score,approved_by=auth.uid(),approved_at=now(),comment=excluded.comment;
end$$;
revoke all on function public.save_self_score(uuid,uuid,numeric,text),public.approve_score_proposal(uuid,numeric,text) from public;
grant execute on function public.save_self_score(uuid,uuid,numeric,text),public.approve_score_proposal(uuid,numeric,text) to authenticated;

create or replace view public.evidence_matrix with (security_invoker=true) as
select ch.id chapter_id,ch.roman,c.id criterion_id,c.code criterion_code,c.legal_text,c.max_score,
 r.id requirement_id,r.title requirement_title,et.category evidence_category,r.mandatory,r.frequency,
 count(e.id) evidence_uploaded,count(e.id) filter(where e.status='approved' and(e.valid_until is null or e.valid_until>=current_date)) evidence_valid,
 case when count(e.id)=0 then 'Chưa có bằng chứng' when count(e.id) filter(where e.status='approved')>=r.minimum_items then 'Đủ bằng chứng hợp lệ' when count(e.id) filter(where e.status in('rejected','expired','withdrawn'))>0 then 'Có bằng chứng nhưng không hợp lệ' else 'Cần bổ sung' end completeness_status
from public.evidence_requirements r join public.criteria c on c.id=r.criterion_id join public.chapters ch on ch.id=c.chapter_id join public.evidence_types et on et.id=r.evidence_type_id left join public.evidence_items e on e.requirement_id=r.id and e.deleted_at is null
group by ch.id,ch.roman,c.id,c.code,c.legal_text,c.max_score,r.id,r.title,et.category,r.mandatory,r.frequency;
grant select on public.evidence_matrix to authenticated;

commit;
