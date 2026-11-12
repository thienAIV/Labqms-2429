import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const jsonHeaders = { 'content-type': 'application/json; charset=utf-8' };

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: jsonHeaders });
  }

  const authorization = req.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'UNAUTHENTICATED' }), { status: 401, headers: jsonHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: 'SERVER_MISCONFIGURED' }), { status: 500, headers: jsonHeaders });
  }

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: 'UNAUTHENTICATED' }), { status: 401, headers: jsonHeaders });
  }

  let body: { documentVersionId?: string; expiresIn?: number };
  try { body = await req.json(); } catch {
    return new Response(JSON.stringify({ error: 'INVALID_JSON' }), { status: 400, headers: jsonHeaders });
  }
  if (!body.documentVersionId || !/^[0-9a-f-]{36}$/i.test(body.documentVersionId)) {
    return new Response(JSON.stringify({ error: 'INVALID_DOCUMENT_VERSION_ID' }), { status: 400, headers: jsonHeaders });
  }
  const expiresIn = Math.min(Math.max(Number(body.expiresIn ?? 300), 60), 900);

  // Caller client is intentionally used for authorization so PostgreSQL RLS is authoritative.
  const { data: version, error: versionError } = await caller
    .from('document_versions')
    .select('id, storage_path, document_id')
    .eq('id', body.documentVersionId)
    .single();
  if (versionError || !version) {
    return new Response(JSON.stringify({ error: 'NOT_FOUND_OR_FORBIDDEN' }), { status: 404, headers: jsonHeaders });
  }

  const { data: signed, error: signedError } = await admin.storage
    .from('documents')
    .createSignedUrl(version.storage_path, expiresIn);
  if (signedError || !signed) {
    return new Response(JSON.stringify({ error: 'SIGNED_URL_FAILED' }), { status: 500, headers: jsonHeaders });
  }

  await admin.from('audit_logs').insert({
    actor_id: userData.user.id,
    action: 'document_signed_url_created',
    entity_type: 'document_version',
    entity_id: version.id,
    details: { expires_in: expiresIn },
  });

  return new Response(JSON.stringify({ signedUrl: signed.signedUrl, expiresIn }), { status: 200, headers: jsonHeaders });
});
