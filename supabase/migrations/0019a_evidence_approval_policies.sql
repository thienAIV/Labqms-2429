begin;

do $$ begin
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='evidence_files' and policyname='evidence_files_insert') then create policy evidence_files_insert on public.evidence_files for insert to authenticated with check(created_by=auth.uid() and exists(select 1 from public.evidence_items e where e.id=evidence_files.evidence_id and e.owner_id=auth.uid() and public.can_read_scope(e.organization_id,e.laboratory_id)));end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='assessment_rounds' and policyname='assessment_rounds_insert') then create policy assessment_rounds_insert on public.assessment_rounds for insert to authenticated with check(created_by=auth.uid() and public.can_read_scope(organization_id,laboratory_id) and public.has_permission('create'));end if;
end $$;

create or replace function public.approve_score(target_proposal uuid,target_score numeric,target_comment text) returns void language plpgsql security definer set search_path=public as $$
declare p public.score_proposals;c public.criteria;begin if not public.has_permission('approve') then raise exception 'FORBIDDEN';end if;if target_comment is null or btrim(target_comment)='' then raise exception 'COMMENT_REQUIRED';end if;select * into p from public.score_proposals where id=target_proposal;select * into c from public.criteria where id=p.criterion_id;if c.verification_status<>'verified' then raise exception 'CRITERION_NOT_VERIFIED';end if;if target_score<0 or target_score>c.max_score then raise exception 'SCORE_OUT_OF_RANGE';end if;insert into public.score_approvals(score_proposal_id,approved_score,approved_by,comment) values(p.id,target_score,auth.uid(),target_comment) on conflict(score_proposal_id) do update set approved_score=excluded.approved_score,approved_by=auth.uid(),approved_at=now(),comment=excluded.comment;end$$;
revoke all on function public.approve_score(uuid,numeric,text) from public;grant execute on function public.approve_score(uuid,numeric,text) to authenticated;

commit;
