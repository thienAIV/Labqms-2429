-- 0012_record_evidence_read_policies.sql
-- Adds the two missing scoped SELECT policies found by the production RLS audit.
-- Non-destructive and idempotent. No write/delete permission is added.
begin;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='record_files'
      and policyname='record_files_read_scope'
  ) then
    create policy record_files_read_scope
    on public.record_files
    for select
    to authenticated
    using (
      exists (
        select 1
        from public.records r
        where r.id = record_files.record_id
          and public.can_read_scope(r.organization_id, r.laboratory_id)
      )
    );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='record_signatures'
      and policyname='record_signatures_read_scope'
  ) then
    create policy record_signatures_read_scope
    on public.record_signatures
    for select
    to authenticated
    using (
      exists (
        select 1
        from public.records r
        where r.id = record_signatures.record_id
          and public.can_read_scope(r.organization_id, r.laboratory_id)
      )
    );
  end if;
end
$$;

commit;
