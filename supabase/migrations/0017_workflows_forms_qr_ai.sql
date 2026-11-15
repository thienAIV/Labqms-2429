-- Operational workflow RPCs, form validation and QR resolution.
begin;

create table if not exists public.ai_action_recommendations (
 id uuid primary key default gen_random_uuid(),
 ai_finding_id uuid not null references public.ai_findings(id) on delete cascade,
 action_type text not null check(action_type in ('task','capa','document_update','record_request','manual_review')),
 recommendation text not null,
 status text not null default 'proposed' check(status in ('proposed','accepted','rejected','implemented')),
 decided_by uuid references public.profiles(id),decided_at timestamptz,created_at timestamptz not null default now(),
 check(status='proposed' or (decided_by is not null and decided_at is not null))
);
alter table public.ai_action_recommendations enable row level security;
create index if not exists ai_action_recommendations_finding_idx on public.ai_action_recommendations(ai_finding_id,status);
do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='ai_action_recommendations' and policyname='ai_recommendations_read') then
  create policy ai_recommendations_read on public.ai_action_recommendations for select to authenticated using(exists(select 1 from public.ai_findings f join public.ai_reviews r on r.id=f.ai_review_id where f.id=ai_action_recommendations.ai_finding_id and public.can_read_scope(r.organization_id,r.laboratory_id)));
 end if;
end $$;

create or replace function public.submit_document_version(target_version uuid) returns void language plpgsql security definer set search_path=public as $$
declare v public.document_versions;begin
 select * into v from public.document_versions where id=target_version for update;
 if v.id is null then raise exception 'VERSION_NOT_FOUND';end if;
 if v.created_by<>auth.uid() and not public.is_lab_admin() then raise exception 'FORBIDDEN';end if;
 if v.status<>'draft' then raise exception 'VERSION_NOT_DRAFT';end if;
 update public.document_versions set status='in_review' where id=v.id;
end$$;
create or replace function public.review_document_version(target_version uuid,target_decision text,target_comment text default null) returns void language plpgsql security definer set search_path=public as $$
declare v public.document_versions;begin
 if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;
 if target_decision not in('approved','changes_requested','rejected') then raise exception 'INVALID_DECISION';end if;
 select * into v from public.document_versions where id=target_version;
 if v.id is null or v.status<>'in_review' then raise exception 'VERSION_NOT_IN_REVIEW';end if;
 if v.created_by=auth.uid() then raise exception 'SEPARATION_OF_DUTIES';end if;
 insert into public.document_reviews(document_version_id,reviewer_id,decision,comment) values(v.id,auth.uid(),target_decision,target_comment) on conflict(document_version_id,reviewer_id) do update set decision=excluded.decision,comment=excluded.comment,reviewed_at=now();
 if target_decision<>'approved' then update public.document_versions set status='draft' where id=v.id;end if;
end$$;
create or replace function public.approve_document_version(target_version uuid,target_decision text,target_comment text default null,target_effective_date date default current_date) returns void language plpgsql security definer set search_path=public as $$
declare v public.document_versions;begin
 if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;
 select * into v from public.document_versions where id=target_version for update;
 if v.created_by=auth.uid() then raise exception 'SEPARATION_OF_DUTIES';end if;
 if not exists(select 1 from public.document_reviews where document_version_id=v.id and decision='approved') then raise exception 'REVIEW_REQUIRED';end if;
 insert into public.document_approvals(document_version_id,approver_id,decision,comment) values(v.id,auth.uid(),target_decision,target_comment) on conflict(document_version_id) do update set approver_id=excluded.approver_id,decision=excluded.decision,comment=excluded.comment,approved_at=now();
 if target_decision='approved' then update public.document_versions set status='approved',approved_by=auth.uid(),approved_at=now(),effective_date=target_effective_date where id=v.id; update public.document_versions set status='superseded' where document_id=v.document_id and id<>v.id and status='approved'; else update public.document_versions set status='draft' where id=v.id;end if;
end$$;
revoke all on function public.submit_document_version(uuid),public.review_document_version(uuid,text,text),public.approve_document_version(uuid,text,text,date) from public;
grant execute on function public.submit_document_version(uuid),public.review_document_version(uuid,text,text),public.approve_document_version(uuid,text,text,date) to authenticated;

create or replace function public.resolve_qr_token(raw_token text) returns table(template_id uuid,template_version_id uuid,template_code text,template_title text) language sql stable security definer set search_path=public as $$
 select t.id,v.id,t.code,t.title from public.qr_codes q join public.form_templates t on t.id=q.template_id join public.form_template_versions v on v.template_id=t.id and v.version_number=t.current_version where q.token_hash=encode(digest(raw_token,'sha256'),'hex') and q.active and (q.expires_at is null or q.expires_at>now()) and public.can_read_scope(t.organization_id,t.laboratory_id) limit 1
$$;
revoke all on function public.resolve_qr_token(text) from public;grant execute on function public.resolve_qr_token(text) to authenticated;

create or replace function public.validate_submission_values() returns trigger language plpgsql set search_path=public as $$
declare f public.form_fields;v numeric;begin select * into f from public.form_fields where id=new.field_id;if f.field_type='number' then v:=(new.value_json#>>'{}')::numeric;if f.min_value is not null and v<f.min_value then raise exception 'VALUE_BELOW_MIN';end if;if f.max_value is not null and v>f.max_value then raise exception 'VALUE_ABOVE_MAX';end if;end if;return new;end$$;
drop trigger if exists trg_validate_submission_values on public.submission_values;create trigger trg_validate_submission_values before insert or update on public.submission_values for each row execute function public.validate_submission_values();

commit;
