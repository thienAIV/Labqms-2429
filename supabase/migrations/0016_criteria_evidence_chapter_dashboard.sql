-- Criteria requirements, evidence mapping, and chapter dashboard. No legal content is seeded.
begin;

create table if not exists public.criterion_requirements (
  id uuid primary key default gen_random_uuid(),
  criterion_id uuid not null references public.criteria(id) on delete cascade,
  requirement_type text not null check (requirement_type in ('legal','document','record','process','personnel','facility','equipment')),
  description text not null,
  mandatory boolean not null default true,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','verified','rejected')),
  source_url text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  check (verification_status <> 'verified' or (source_url is not null and verified_by is not null and verified_at is not null))
);
create table if not exists public.criterion_documents (
  criterion_id uuid not null references public.criteria(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete restrict,
  linked_by uuid not null references public.profiles(id),
  linked_at timestamptz not null default now(),
  primary key (criterion_id,document_id)
);
create table if not exists public.criterion_records (
  criterion_id uuid not null references public.criteria(id) on delete cascade,
  record_id uuid not null references public.records(id) on delete restrict,
  linked_by uuid not null references public.profiles(id),
  linked_at timestamptz not null default now(),
  primary key (criterion_id,record_id)
);
create index if not exists criterion_requirements_criterion_idx on public.criterion_requirements(criterion_id,verification_status);
create index if not exists criterion_documents_document_idx on public.criterion_documents(document_id);
create index if not exists criterion_records_record_idx on public.criterion_records(record_id);
alter table public.criterion_requirements enable row level security;
alter table public.criterion_documents enable row level security;
alter table public.criterion_records enable row level security;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_requirements' and policyname='criterion_requirements_read') then
  create policy criterion_requirements_read on public.criterion_requirements for select to authenticated using(public.is_approved_user());
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_requirements' and policyname='criterion_requirements_admin_write') then
  create policy criterion_requirements_admin_write on public.criterion_requirements for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_documents' and policyname='criterion_documents_read') then
  create policy criterion_documents_read on public.criterion_documents for select to authenticated using(exists(select 1 from public.documents d where d.id=criterion_documents.document_id));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_documents' and policyname='criterion_documents_write') then
  create policy criterion_documents_write on public.criterion_documents for all to authenticated using(public.has_permission('update')) with check(linked_by=auth.uid() and public.has_permission('update'));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_records' and policyname='criterion_records_read') then
  create policy criterion_records_read on public.criterion_records for select to authenticated using(exists(select 1 from public.records r where r.id=criterion_records.record_id));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='criterion_records' and policyname='criterion_records_write') then
  create policy criterion_records_write on public.criterion_records for all to authenticated using(public.has_permission('update')) with check(linked_by=auth.uid() and public.has_permission('update'));
 end if;
end $$;

create or replace view public.chapter_quality_dashboard with (security_invoker=true) as
select ch.id as chapter_id,ch.roman,ch.name,
 count(distinct c.id) as criteria_total,
 count(distinct c.id) filter(where c.verification_status='verified') as criteria_verified,
 count(distinct cd.criterion_id) as criteria_with_documents,
 count(distinct cr.criterion_id) as criteria_with_records,
 count(distinct c.id) filter(where c.verification_status='verified' and cd.criterion_id is null) as missing_documents,
 count(distinct c.id) filter(where c.verification_status='verified' and cr.criterion_id is null) as missing_records
from public.chapters ch
left join public.criteria c on c.chapter_id=ch.id
left join public.criterion_documents cd on cd.criterion_id=c.id
left join public.criterion_records cr on cr.criterion_id=c.id
group by ch.id,ch.roman,ch.name;
grant select on public.chapter_quality_dashboard to authenticated;

commit;
