-- Read-only audit after a batch is loaded.
select * from public.legal_import_progress order by batch_version;
select chapter_id,count(*) criteria_count,sum(max_score) max_score from public.legal_import_rows where batch_id=:batch_id group by chapter_id order by chapter_id;
select normalized_code,count(*) from public.legal_import_rows where batch_id=:batch_id group by normalized_code having count(*)>1;
select count(*) incomplete_rows from public.legal_import_rows where batch_id=:batch_id and(length(trim(legal_text))<10 or source_page<1 or source_excerpt_hash is null);
