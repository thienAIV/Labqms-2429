begin;

create or replace function public.invalidate_record_signatures()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record_id uuid;
  v_reason text;
begin
  if tg_table_name='records' then
    v_record_id:=coalesce(new.id,old.id);
    v_reason:='Hồ sơ đã thay đổi sau khi ký';
  elsif tg_table_name='record_files' then
    v_record_id:=coalesce(new.record_id,old.record_id);
    v_reason:='File minh chứng của hồ sơ đã thay đổi sau khi ký';
  else
    raise exception 'UNSUPPORTED_SIGNATURE_INVALIDATION_SOURCE';
  end if;
  update public.record_signatures
  set invalidated_at=now(), invalidated_reason=v_reason
  where record_id=v_record_id and invalidated_at is null;
  return coalesce(new,old);
end;
$$;
revoke all on function public.invalidate_record_signatures() from public,anon,authenticated;

drop trigger if exists trg_invalidate_signature_on_record_update on public.records;
create trigger trg_invalidate_signature_on_record_update
after update on public.records for each row
when (old is distinct from new)
execute function public.invalidate_record_signatures();

drop trigger if exists trg_invalidate_signature_on_record_file_change on public.record_files;
create trigger trg_invalidate_signature_on_record_file_change
after insert or update or delete on public.record_files for each row
execute function public.invalidate_record_signatures();

commit;
