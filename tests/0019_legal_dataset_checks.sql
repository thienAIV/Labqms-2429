-- Read-only checks after importing and verifying all official criterion rows.
select count(*) as chapters from public.chapters;
select count(*) as criteria_total,sum(max_score) as max_score_total from public.criteria where verification_status='verified';
select chapter_id,count(*) criteria_count,sum(max_score) max_score from public.criteria where verification_status='verified' group by chapter_id order by chapter_id;
select code,count(*) from public.criteria group by code having count(*)>1;
select count(*) as verified_without_provenance from public.criteria where verification_status='verified' and(source_url is null or verified_by is null or verified_at is null or legal_source_id is null or source_page is null);
