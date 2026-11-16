select chapter_id,criteria_total,criteria_verified,criteria_unverified,
 criteria_with_documents,criteria_with_records,missing_documents,missing_records
from public.chapter_quality_dashboard order by chapter_id;
select chapter_id,count(*) total,count(*) filter(where verification_status='verified') verified
from public.criteria where deleted_at is null group by chapter_id order by chapter_id;
