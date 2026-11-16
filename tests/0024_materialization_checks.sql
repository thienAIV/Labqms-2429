select chapter_id,count(*) criteria_count,sum(max_score) max_score,
 count(*) filter(where verification_status='verified') verified_count
from public.criteria where legal_data_version='QD2429-2017-v1'
group by chapter_id order by chapter_id;
select count(*) criteria_total,sum(max_score) max_score_total,
 count(*) filter(where verification_status='verified') verified_total
from public.criteria where legal_data_version='QD2429-2017-v1';
select et.category,count(*) requirement_count,count(*) filter(where er.verification_status='verified') verified_requirements
from public.evidence_requirements er join public.evidence_types et on et.id=er.evidence_type_id
join public.criteria c on c.id=er.criterion_id where c.legal_data_version='QD2429-2017-v1'
group by et.category order by et.category;
