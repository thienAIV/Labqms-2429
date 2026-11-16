# Double-review rules

- Two different approved administrators must independently compare every staged criterion with the supplied PDF.
- Both reviews must match on legal text, score, mandatory-star level, partial-scoring flag, source page, and excerpt SHA-256.
- Placeholder text is rejected.
- Any mismatch keeps the row in `needs_revision`.
- Only matching independent reviews set a row to `approved`.
- Batch approval remains blocked until all 169 rows are approved.
