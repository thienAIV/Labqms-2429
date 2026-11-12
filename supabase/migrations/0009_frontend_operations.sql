begin;

-- Assign approved users to the approving admin's scope.
create or replace function public.approve_user(target_user uuid,target_role public.app_role default 'staff')
returns void language plpgsql security definer set search_path=public
as $$
declare v_org uuid; v_lab uuid;
begin
  if not public.is_lab_admin() then raise exception 'FORBIDDEN'; end if;
  if target_role='super_admin' and not exists(select 1 from public.profiles where id=auth.uid() and role='super_admin') then raise exception 'SUPER_ADMIN_REQUIRED'; end if;
  select organization_id,laboratory_id into v_org,v_lab from public.profiles where id=auth.uid();
  if v_org is null or v_lab is null then raise exception 'ADMIN_SCOPE_NOT_CONFIGURED'; end if;
  update public.profiles set status='approved',role=target_role,organization_id=v_org,laboratory_id=v_lab,approved_at=now(),approved_by=auth.uid() where id=target_user and status='pending';
  if not found then raise exception 'PENDING_PROFILE_NOT_FOUND'; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details) values(auth.uid(),'user_approved','profile',target_user::text,jsonb_build_object('role',target_role,'organization_id',v_org,'laboratory_id',v_lab));
end $$;

-- Complete read policies required by dashboard and CAPA screens.
create policy capa_actions_read_scope on public.capa_actions for select to authenticated
using(exists(select 1 from public.nonconformities n join public.profiles p on p.id=auth.uid() where n.id=capa_actions.nonconformity_id and p.status='approved' and (public.is_lab_admin() or p.laboratory_id=n.laboratory_id)));
create policy capa_effectiveness_read_scope on public.capa_effectiveness_reviews for select to authenticated
using(exists(select 1 from public.capa_actions a join public.nonconformities n on n.id=a.nonconformity_id join public.profiles p on p.id=auth.uid() where a.id=capa_effectiveness_reviews.action_id and p.status='approved' and (public.is_lab_admin() or p.laboratory_id=n.laboratory_id)));

-- Admins may update documents inside their laboratory. Approved versions remain immutable in app flow.
create policy documents_admin_update on public.documents for update to authenticated
using(public.is_lab_admin()) with check(public.is_lab_admin());

commit;
