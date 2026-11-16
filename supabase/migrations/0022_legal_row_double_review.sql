-- Independent double-review workflow for staged QD 2429 legal rows.
begin;

create table if not exists public.legal_row_reviews(
 id uuid primary key default gen_random_uuid(),
 import_row_id uuid not null references public.legal_import_rows(id) on delete cascade,
 review_round smallint not null check(review_round in(1,2)),
 reviewer_id uuid not null references public.profiles(id),
 decision text not null check(decision in('matched','needs_revision','rejected')),
 checked_legal_text text not null,
 checked_max_score numeric not null check(checked_max_score>0),
 checked_mandatory_level text not null check(checked_mandatory_level in('none','level_1','level_3')),
 checked_partial_allowed boolean not null,
 source_page integer not null check(source_page>0),
 excerpt_sha256 text not null check(excerpt_sha256~'^[a-f0-9]{64}$'),
 comment text not null,
 created_at timestamptz not null default now(),
 unique(import_row_id,review_round),
 unique(import_row_id,reviewer_id)
);
create index if not exists legal_row_reviews_row_idx on public.legal_row_reviews(import_row_id,review_round);
alter table public.legal_row_reviews enable row level security;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='legal_row_reviews' and policyname='legal_row_reviews_read') then
  create policy legal_row_reviews_read on public.legal_row_reviews for select to authenticated using(public.is_lab_admin());
 end if;
end $$;

create or replace function public.submit_legal_row_review(
 target_row uuid,target_round smallint,target_decision text,target_legal_text text,target_max_score numeric,
 target_mandatory_level text,target_partial_allowed boolean,target_source_page integer,target_excerpt_sha256 text,target_comment text
) returns void language plpgsql security definer set search_path=public as $$
declare r public.legal_import_rows;prior uuid;begin
 if not public.is_lab_admin() then raise exception 'FORBIDDEN';end if;
 if target_round not in(1,2) then raise exception 'INVALID_REVIEW_ROUND';end if;
 if target_decision not in('matched','needs_revision','rejected') then raise exception 'INVALID_DECISION';end if;
 if length(trim(target_legal_text))<10 or target_legal_text like 'Chờ quản trị viên xác minh%' then raise exception 'LEGAL_TEXT_NOT_VERIFIED';end if;
 if target_comment is null or length(trim(target_comment))<3 then raise exception 'COMMENT_REQUIRED';end if;
 select * into r from public.legal_import_rows where id=target_row for update;
 if r.id is null then raise exception 'IMPORT_ROW_NOT_FOUND';end if;
 if target_round=2 then
  select reviewer_id into prior from public.legal_row_reviews where import_row_id=r.id and review_round=1 and decision='matched';
  if prior is null then raise exception 'ROUND_ONE_MATCH_REQUIRED';end if;
  if prior=auth.uid() then raise exception 'INDEPENDENT_REVIEWER_REQUIRED';end if;
 end if;
 insert into public.legal_row_reviews(import_row_id,review_round,reviewer_id,decision,checked_legal_text,checked_max_score,checked_mandatory_level,checked_partial_allowed,source_page,excerpt_sha256,comment)
 values(r.id,target_round,auth.uid(),target_decision,target_legal_text,target_max_score,target_mandatory_level,target_partial_allowed,target_source_page,target_excerpt_sha256,target_comment)
 on conflict(import_row_id,review_round) do update set reviewer_id=auth.uid(),decision=excluded.decision,checked_legal_text=excluded.checked_legal_text,checked_max_score=excluded.checked_max_score,checked_mandatory_level=excluded.checked_mandatory_level,checked_partial_allowed=excluded.checked_partial_allowed,source_page=excluded.source_page,excerpt_sha256=excluded.excerpt_sha256,comment=excluded.comment,created_at=now();
 if target_decision<>'matched' then
  update public.legal_import_rows set row_status='needs_revision',reviewer_note=target_comment where id=r.id;
 elsif target_round=2 then
  if not exists(
   select 1 from public.legal_row_reviews a join public.legal_row_reviews b on b.import_row_id=a.import_row_id
   where a.import_row_id=r.id and a.review_round=1 and b.review_round=2 and a.decision='matched' and b.decision='matched'
    and a.checked_legal_text=b.checked_legal_text and a.checked_max_score=b.checked_max_score
    and a.checked_mandatory_level=b.checked_mandatory_level and a.checked_partial_allowed=b.checked_partial_allowed
    and a.source_page=b.source_page and a.excerpt_sha256=b.excerpt_sha256
  ) then raise exception 'DOUBLE_REVIEW_MISMATCH';end if;
  update public.legal_import_rows set legal_text=target_legal_text,max_score=target_max_score,mandatory_level=target_mandatory_level,partial_allowed=target_partial_allowed,source_page=target_source_page,source_excerpt_hash=target_excerpt_sha256,row_status='approved',reviewer_note='Đã đối chiếu độc lập hai lượt.' where id=r.id;
 else
  update public.legal_import_rows set row_status='in_review',reviewer_note='Đã hoàn thành lượt đối chiếu thứ nhất.' where id=r.id;
 end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,details) values(auth.uid(),'legal_row_review_submitted','legal_import_row',r.id::text,jsonb_build_object('round',target_round,'decision',target_decision));
end$$;
revoke all on function public.submit_legal_row_review(uuid,smallint,text,text,numeric,text,boolean,integer,text,text) from public;
grant execute on function public.submit_legal_row_review(uuid,smallint,text,text,numeric,text,boolean,integer,text,text) to authenticated;

create or replace view public.legal_double_review_progress with(security_invoker=true) as
select b.id batch_id,b.batch_version,b.status,count(r.id) rows_total,
 count(r.id) filter(where r.row_status='approved') rows_double_checked,
 count(r.id) filter(where r.row_status='needs_revision') rows_needing_revision,
 count(rv.id) filter(where rv.review_round=1 and rv.decision='matched') round_one_matched,
 count(rv.id) filter(where rv.review_round=2 and rv.decision='matched') round_two_matched
from public.legal_import_batches b left join public.legal_import_rows r on r.batch_id=b.id left join public.legal_row_reviews rv on rv.import_row_id=r.id
group by b.id,b.batch_version,b.status;
grant select on public.legal_double_review_progress to authenticated;

commit;
