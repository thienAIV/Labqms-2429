# Trạng thái nghiệm thu v2.5.0-rc.1

- P0 implemented in source: company-domain auth, pending gate, scoped RLS, ordered chapters, chapter details, real dashboards, private Storage/signed URL, evidence rules, expert review, final approval, official score approvals, audit, Realtime.
- P1 implemented in source: evidence matrix, document lifecycle, record signatures/invalidation, CAPA, forms/QR token, reminders, AI review architecture.
- Legal dataset remains unverified as intended: 169 staging rows are `needs_revision`; no official score uses them.
- AI provider is disabled until server-side secrets are configured and approved.
- Production status requires Vercel build and runtime acceptance test evidence.
