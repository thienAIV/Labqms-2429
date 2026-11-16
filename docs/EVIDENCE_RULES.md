# Quy tắc bằng chứng

- Legal criteria are never seeded from AI or secondary guidance.
- Only `criteria.verification_status=verified` with source, verifier, and verification date can enter scoring.
- Upload creates `evidence_items.status=automatic_check`; upload itself never grants points.
- Rules engine returns PASS, FAIL, WARNING, NOT_APPLICABLE, or NEEDS_HUMAN_REVIEW.
- Expert reviewer cannot be the evidence owner. Any FAIL blocks approval.
- Only `evidence_items.status=approved` and unexpired evidence satisfies a mandatory requirement.
- Only `score_approvals.approved_score` is official.
