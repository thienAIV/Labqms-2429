-- 0011_complete_read_policies.sql
-- Adds missing, scoped SELECT policies only. Non-destructive and idempotent.
begin;

-- Helper: super admin or approved user in a specific organization/laboratory.
create or replace function public.can_read_scope(target_organization uuid, target_laboratory uuid default null)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.status='approved'
      and (
        p.role='super_admin'
        or (
          p.organization_id=target_organization
          and (target_laboratory is null or p.laboratory_id=target_laboratory)
        )
      )
  )
$$;
revoke all on function public.can_read_scope(uuid,uuid) from public;
grant execute on function public.can_read_scope(uuid,uuid) to authenticated;

-- Create policies only when absent, so reruns do not fail.
do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='organizations' and policyname='organizations_read_scope') then
  create policy organizations_read_scope on public.organizations for select to authenticated
  using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.status='approved' and (p.role='super_admin' or p.organization_id=organizations.id)));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='laboratories' and policyname='laboratories_read_scope') then
  create policy laboratories_read_scope on public.laboratories for select to authenticated
  using(public.can_read_scope(organization_id,id));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='form_templates' and policyname='form_templates_read_scope') then
  create policy form_templates_read_scope on public.form_templates for select to authenticated
  using(public.can_read_scope(organization_id,laboratory_id));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='form_template_versions' and policyname='form_template_versions_read_scope') then
  create policy form_template_versions_read_scope on public.form_template_versions for select to authenticated
  using(exists(select 1 from public.form_templates t where t.id=form_template_versions.template_id and public.can_read_scope(t.organization_id,t.laboratory_id)));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='qr_codes' and policyname='qr_codes_read_scope') then
  create policy qr_codes_read_scope on public.qr_codes for select to authenticated
  using(exists(select 1 from public.form_templates t where t.id=qr_codes.template_id and public.can_read_scope(t.organization_id,t.laboratory_id)));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='capa_actions' and policyname='capa_actions_read_scope') then
  create policy capa_actions_read_scope on public.capa_actions for select to authenticated
  using(exists(select 1 from public.nonconformities n where n.id=capa_actions.nonconformity_id and public.can_read_scope(n.organization_id,n.laboratory_id)));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='capa_effectiveness_reviews' and policyname='capa_effectiveness_read_scope') then
  create policy capa_effectiveness_read_scope on public.capa_effectiveness_reviews for select to authenticated
  using(exists(select 1 from public.capa_actions a join public.nonconformities n on n.id=a.nonconformity_id where a.id=capa_effectiveness_reviews.action_id and public.can_read_scope(n.organization_id,n.laboratory_id)));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='ai_reviews' and policyname='ai_reviews_read_scope') then
  create policy ai_reviews_read_scope on public.ai_reviews for select to authenticated
  using(public.can_read_scope(organization_id,laboratory_id));
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='ai_findings' and policyname='ai_findings_read_scope') then
  create policy ai_findings_read_scope on public.ai_findings for select to authenticated
  using(exists(select 1 from public.ai_reviews r where r.id=ai_findings.ai_review_id and public.can_read_scope(r.organization_id,r.laboratory_id)));
 end if;
end $$;

commit;
