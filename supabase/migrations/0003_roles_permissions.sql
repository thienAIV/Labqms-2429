begin;

create table if not exists public.permissions (
  code text primary key,
  description text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role public.app_role not null,
  permission_code text not null references public.permissions(code) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role, permission_code)
);

alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;

insert into public.permissions(code,description) values
('view','Xem dữ liệu trong phạm vi được cấp'),
('create','Tạo dữ liệu trong phạm vi được cấp'),
('update','Cập nhật dữ liệu trong phạm vi được cấp'),
('submit','Gửi dữ liệu hoặc tài liệu để duyệt'),
('approve','Phê duyệt dữ liệu hoặc tài liệu'),
('download','Tải file trong phạm vi được cấp'),
('export','Xuất báo cáo'),
('administer','Quản trị cấu hình và phân quyền')
on conflict(code) do update set description=excluded.description;

insert into public.role_permissions(role,permission_code) values
('super_admin','view'),('super_admin','create'),('super_admin','update'),('super_admin','submit'),('super_admin','approve'),('super_admin','download'),('super_admin','export'),('super_admin','administer'),
('lab_admin','view'),('lab_admin','create'),('lab_admin','update'),('lab_admin','submit'),('lab_admin','approve'),('lab_admin','download'),('lab_admin','export'),('lab_admin','administer'),
('quality_manager','view'),('quality_manager','create'),('quality_manager','update'),('quality_manager','submit'),('quality_manager','download'),('quality_manager','export'),
('chapter_lead','view'),('chapter_lead','create'),('chapter_lead','update'),('chapter_lead','submit'),('chapter_lead','download'),
('staff','view'),('staff','create'),('staff','update'),('staff','submit'),('staff','download'),
('viewer','view'),('viewer','download')
on conflict do nothing;

create or replace function public.has_permission(required_permission text)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(
    select 1 from public.profiles p
    join public.role_permissions rp on rp.role=p.role
    where p.id=auth.uid() and p.status='approved' and rp.permission_code=required_permission
  )
$$;

create policy permissions_read_approved on public.permissions
for select to authenticated using(public.is_approved_user());
create policy role_permissions_read_approved on public.role_permissions
for select to authenticated using(public.is_approved_user());

revoke all on function public.has_permission(text) from public;
grant execute on function public.has_permission(text) to authenticated;

commit;
