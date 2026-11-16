# LabQMS 2429 legal patch v2.3.1

This patch registers the user-provided authoritative PDF, versions legal criteria, hardens partial scoring, and classifies approved assessments under the official 2429 thresholds and mandatory-star conditions.

It intentionally does not mark OCR-extracted criterion text as verified. Full import must retain source page and be double-checked before `verified` status.

Apply after migrations 0018 and only after a successful clean Vercel build of the matching repository.
