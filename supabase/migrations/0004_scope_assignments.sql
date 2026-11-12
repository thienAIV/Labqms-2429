begin;

alter table public.profiles add column if not exists organization_id uuid references public.organizations(id);
create index if not exists profiles_organization_idx on public.profiles(organization_id);
create index if not exists profiles_laboratory_idx on public.profiles(laboratory_id);

create table if not exists public.user_chapter_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  laboratory_id uuid not null references public.laboratories(id) on delete cascade,
  chapter_id smallint not null references public.chapters(id) on delete cascade,
  can_view boolean not null default true,
  can_create boolean not null default false,
  can_update boolean not null default false,
  can_submit boolean not null default false,
  can_approve boolean not null default false,
  assigned_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(user_id,laboratory_id,chapter_id)
);

create table if not exists public.user_criterion_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  criterion_id uuid not null references public.criteria(id) on delete cascade,
  can_view boolean not null default true,
  can_create boolean not null default false,
  can_update boolean not null default false,
  can_submit boolean not null default false,
  can_approve boolean not null default false,
  assigned_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(user_id,criterion_id)
);

create index if not exists user_chapter_user_idx on public.user_chapter_assignments(user_id);
create index if not exists user_chapter_scope_idx on public.user_chapter_assignments(laboratory_id,chapter_id);
create index if not exists user_criterion_user_idx on public.user_criterion_assignments(user_id);
create index if not exists user_criterion_criterion_idx on public.user_criterion_assignments(criterion_id);

alter table public.user_chapter_assignments enable row level security;
alter table public.user_criterion_assignments enable row level security;

create policy chapter_assignment_read_self_or_admin on public.user_chapter_assignments
for select to authenticated using(user_id=auth.uid() or public.is_lab_admin());
create policy chapter_assignment_admin_write on public.user_chapter_assignments
for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());
create policy criterion_assignment_read_self_or_admin on public.user_criterion_assignments
for select to authenticated using(user_id=auth.uid() or public.is_lab_admin());
create policy criterion_assignment_admin_write on public.user_criterion_assignments
for all to authenticated using(public.is_lab_admin()) with check(public.is_lab_admin());

create or replace function public.has_chapter_action(target_laboratory uuid,target_chapter smallint,required_action text)
returns boolean language sql stable security definer set search_path=public
as $$
 select public.is_lab_admin() or exists(
  select 1 from public.user_chapter_assignments a
  join public.profiles p on p.id=a.user_id
  where a.user_id=auth.uid() and p.status='approved'
    and a.laboratory_id=target_laboratory and a.chapter_id=target_chapter
    and case required_action
      when 'view' then a.can_view when 'create' then a.can_create
      when 'update' then a.can_update when 'submit' then a.can_submit
      when 'approve' then a.can_approve else false end
 )
$$;
revoke all on function public.has_chapter_action(uuid,smallint,text) from public;
grant execute on function public.has_chapter_action(uuid,smallint,text) to authenticated;

commit;
