# create-document-signed-url

Authenticated Edge Function issuing a private Storage signed URL for 60–900 seconds. Authorization is delegated to `document_versions` RLS. The service role is used only after the caller has passed RLS and never returned to the browser.

Request:
```json
{"documentVersionId":"uuid","expiresIn":300}
```

Deploy with JWT verification enabled. Required Supabase-provided secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
