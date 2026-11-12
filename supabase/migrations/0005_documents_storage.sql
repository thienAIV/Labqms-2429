begin;

create type public.document_status as enum ('draft','in_review','approved','superseded','expired','withdrawn');

create table public.documents (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 laboratory_id uuid not null references public.laboratories(id),
 chapter_id smallint references public.chapters(id),
 code text not null,
 title text not null,
 owner_id uuid not null references public.profiles(id),
 current_version integer not null default 0 check(current_version>=0),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 unique(laboratory_id,code)
);

create table public.document_versions (
 id uuid primary key default gen_random_uuid(),
 document_id uuid not null references public.documents(id) on delete restrict,
 version_number integer not null check(version_number>0),
 status public.document_status not null default 'draft',
 storage_path text not null unique,
 file_name text not null,
 mime_type text not null,
 file_size bigint not null check(file_size>0 and file_size<=52428800),
 checksum_sha256 text not null check(checksum_sha256 ~ '^[a-f0-9]{64}$'),
 effective_date date,
 review_due_date date,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 unique(document_id,version_number),
 check(status<>'approved' or (approved_by is not null and approved_at is not null and effective_date is not null))
);

create index documents_scope_idx on public.documents(organization_id,laboratory_id,chapter_id) where deleted_at is null;
create index document_versions_document_idx on public.document_versions(document_id,version_number desc);
alter table public.documents enable row level security;
alter table public.document_versions enable row level security;

create policy documents_read_scoped on public.documents for select to authenticated
using(deleted_at is null and (public.is_lab_admin() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.status='approved' and p.laboratory_id=documents.laboratory_id)));
create policy documents_create_scoped on public.documents for insert to authenticated
with check(public.has_permission('create') and exists(select 1 from public.profiles p where p.id=auth.uid() and p.laboratory_id=documents.laboratory_id));
create policy document_versions_read_scoped on public.document_versions for select to authenticated
using(exists(select 1 from public.documents d where d.id=document_versions.document_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('documents','documents',false,52428800,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy storage_documents_read on storage.objects for select to authenticated
using(bucket_id='documents' and exists(
 select 1 from public.documents d
 join public.profiles p on p.id=auth.uid()
 where p.status='approved' and (public.is_lab_admin() or p.laboratory_id=d.laboratory_id)
 and (storage.foldername(name))[1]=d.organization_id::text
 and (storage.foldername(name))[2]=d.laboratory_id::text
));
create policy storage_documents_insert on storage.objects for insert to authenticated
with check(bucket_id='documents' and public.has_permission('create') and exists(
 select 1 from public.profiles p where p.id=auth.uid() and p.status='approved'
 and (storage.foldername(name))[1]=p.organization_id::text
 and (storage.foldername(name))[2]=p.laboratory_id::text
));

commit;
