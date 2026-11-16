# Migration manifest v2.5.0-rc.1

Production already confirmed through 0021. Apply next:
1. `0022_legal_row_double_review.sql`
2. `0023_acceptance_hardening.sql`

Historical note: `0019a_evidence_approval_policies.sql` was formerly named `0019_evidence_approval_policies.sql`. It is preserved for repository history and must not be rerun on a database where it already succeeded.
