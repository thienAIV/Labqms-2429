-- 0010_release_hardening.sql
-- Non-destructive hardening for the v1.2 release candidate.
begin;

-- Legal provenance fields. Existing criteria remain unverified.
alter table public.criteria add column if not exists sequence_number integer;
alter table public.criteria add column if not exists achievement_condition text;
alter table public.criteria add column if not exists required_evidence text;
alter table public.criteria add column if not exists evidence_type text;
alter table public.criteria add column if not exists suggested_evidence text;
alter table public.criteria add column if not exists ai_recommendation text;
alter table public.criteria add column if not exists update_frequency text;
alter table public.criteria add column if not exists responsible_unit text;
alter table public.criteria add column if not exists responsible_user_id uuid references public.profiles(id);
alter table public.criteria add column if not exists legal_data_version text;
alter table public.criteria add column if not exists source_document text;
create index if not exists criteria_chapter_sequence_idx on public.criteria(chapter_id,sequence_number);
create index if not exists criteria_verification_idx on public.criteria(verification_status);

-- Document review and approval separation of duties.
create table if not exists public.document_reviews(
 id uuid primary key default gen_random_uuid(),
 document_version_id uuid not null references public.document_versions(id) on delete restrict,
 reviewer_id uuid not null references public.profiles(id),
 decision text not null check(decision in ('approved','changes_requested','rejected')),
 comment text,
 reviewed_at timestamptz not null default now(),
 unique(document_version_id,reviewer_id)
);
create table if not exists public.document_approvals(
 id uuid primary key default gen_random_uuid(),
 document_version_id uuid not null unique references public.document_versions(id) on delete restrict,
 approver_id uuid not null references public.profiles(id),
 decision text not null check(decision in ('approved','rejected')),
 comment text,
 approved_at timestamptz not null default now()
);
alter table public.document_reviews enable row level security;
alter table public.document_approvals enable row level security;
create policy document_reviews_read_scoped on public.document_reviews for select to authenticated
using(exists(select 1 from public.document_versions v join public.documents d on d.id=v.document_id join public.profiles p on p.id=auth.uid() where v.id=document_reviews.document_version_id and p.status='approved' and (public.is_lab_admin() or p.laboratory_id=d.laboratory_id)));
create policy document_approvals_read_scoped on public.document_approvals for select to authenticated
using(exists(select 1 from public.document_versions v join public.documents d on d.id=v.document_id join public.profiles p on p.id=auth.uid() where v.id=document_approvals.document_version_id and p.status='approved' and (public.is_lab_admin() or p.laboratory_id=d.laboratory_id)));

-- Prevent ordinary API clients from changing immutable audit events.
revoke insert,update,delete,truncate on public.audit_logs from anon,authenticated;

-- Explicitly protect AI findings from machine-side self-approval through normal API.
revoke update,delete on public.ai_findings from anon;

-- CSV support in private document bucket.
update storage.buckets set public=false,
 allowed_mime_types=array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv','image/jpeg','image/png']
where id='documents';

commit;
