-- Read-only release audit.
select schemaname,tablename,rowsecurity from pg_tables where schemaname='public' order by tablename;
select id,name,public,file_size_limit,allowed_mime_types from storage.buckets order by id;
select status,role,count(*) from public.profiles group by status,role order by status,role;
select verification_status,count(*) from public.criteria group by verification_status;
select count(*) as orphan_document_versions from public.document_versions v left join public.documents d on d.id=v.document_id where d.id is null;
select count(*) as orphan_record_files from public.record_files f left join public.records r on r.id=f.record_id where r.id is null;
