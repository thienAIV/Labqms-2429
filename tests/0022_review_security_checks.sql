-- Expected runtime checks on a test project:
-- 1. Same reviewer in rounds 1 and 2 -> INDEPENDENT_REVIEWER_REQUIRED.
-- 2. Round 2 without matched round 1 -> ROUND_ONE_MATCH_REQUIRED.
-- 3. Placeholder legal text -> LEGAL_TEXT_NOT_VERIFIED.
-- 4. Any mismatch between two matched reviews -> DOUBLE_REVIEW_MISMATCH.
-- 5. Row becomes approved only after identical independent reviews.
select * from public.legal_double_review_progress where batch_version='QD2429-2017-v1';
