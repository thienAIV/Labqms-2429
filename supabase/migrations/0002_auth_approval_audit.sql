-- 0002: server-side company email validation, profile provisioning, approval and immutable audit log.
begin;

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.audit_logs enable row level security;

create or replace function public.is_approved_user()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and status='approved') $$;

create or replace function public.is_lab_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and status='approved' and role in ('super_admin','lab_admin')) $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if lower(new.email) !~ '^[^@]+@sungrouphospital\.com$' then
    raise exception 'EMAIL_DOMAIN_NOT_ALLOWED';
  end if;
  insert into public.profiles(id,email,full_name,status,role)
  values(new.id,lower(new.email),nullif(trim(new.raw_user_meta_data->>'full_name'),''),'pending','staff')
  on conflict(id) do nothing;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details)
  values(new.id,'account_registered','profile',new.id::text,jsonb_build_object('email',lower(new.email)));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.claim_first_super_admin()
returns boolean language plpgsql security definer set search_path=public
as $$
declare claimed boolean:=false;
begin
  perform pg_advisory_xact_lock(2429);
  if not exists(select 1 from public.profiles where role='super_admin' and status='approved') then
    update public.profiles set role='super_admin',status='approved',approved_at=now(),approved_by=auth.uid() where id=auth.uid() and email like '%@sungrouphospital.com';
    claimed:=found;
    if claimed then insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'first_super_admin_claimed','profile',auth.uid()::text); end if;
  end if;
  return claimed;
end $$;
grant execute on function public.claim_first_super_admin() to authenticated;

create or replace function public.approve_user(target_user uuid,target_role public.app_role default 'staff')
returns void language plpgsql security definer set search_path=public
as $$
begin
  if not public.is_lab_admin() then raise exception 'FORBIDDEN'; end if;
  if target_role='super_admin' and not exists(select 1 from public.profiles where id=auth.uid() and role='super_admin') then raise exception 'SUPER_ADMIN_REQUIRED'; end if;
  update public.profiles set status='approved',role=target_role,approved_at=now(),approved_by=auth.uid() where id=target_user;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details) values(auth.uid(),'user_approved','profile',target_user::text,jsonb_build_object('role',target_role));
end $$;
revoke all on function public.approve_user(uuid,public.app_role) from public;
grant execute on function public.approve_user(uuid,public.app_role) to authenticated;

create policy audit_read_admin on public.audit_logs for select to authenticated using(public.is_lab_admin());
create policy profiles_admin_read on public.profiles for select to authenticated using(public.is_lab_admin());

drop policy if exists chapters_read_approved on public.chapters;
create policy chapters_read_approved on public.chapters for select to authenticated using(public.is_approved_user());
drop policy if exists criteria_read_approved on public.criteria;
create policy criteria_read_approved on public.criteria for select to authenticated using(public.is_approved_user());

commit;
