# Admin CSV Question Bank Template — Instructions and Validation

This ZIP includes *real downloadable usable CSV files*:

- `CAMPUS_LEAGUE/ADMIN_MCQ_TEMPLATE_BLANK.csv` (headers, no rows)
- `CAMPUS_LEAGUE/ADMIN_MCQ_TEMPLATE_SAMPLE.csv` (fully populated DEMONSTRATION rows; not production-approved educational content; must be faculty-reviewed)
- `CAMPUS_LEAGUE/ADMIN_MCQ_SCHEMA.json` (structured field requirements, sample options and import rules)

## Required CSV fields

`question_id,professional_year,subject,topic,question,option_a,option_b,option_c,option_d,correct_option,explanation,difficulty,status`

- `question_id` required stable alphanumeric/safe key unique across import and server question bank. Never auto-overwrite active/historic questions.
- `professional_year` required; use canonical controlled values (`1`..`5` initially, configurable to actual app/institution). Subject-to-year mapping **must be verified from real academic dataset**; sample rows are demo only, not curriculum authority.
- `subject` and `topic` required values matched to controlled database labels/IDs; trim whitespace, guard case/aliases before import.
- `question` and `option_a`..`option_d` all required non-empty strings; keep CSV quoting correct for commas, Unicode and line breaks. Reject dangerous HTML/script and spreadsheet-formula prefixed strings if content could be exported back to Excel; sanitize on output rather than destroy educational text silently.
- `correct_option` one of `A`, `B`, `C`, `D`, server/private. Validate and avoid accidental answer leak on preview to student.
- `explanation` optional but encouraged for post-quiz academic feedback only when permitted.
- `difficulty` optional `easy` / `medium` / `hard`, only use if admin provides; no fake AI-generated difficulty label as established truth.
- `status`: `draft` or `active` (default should be draft for imported examples), server publish requires approval/permissions and enough eligible MCQs. Never silently publish sample questions.

## How admin uses files

1. Download *blank* or *sample* CSV in Admin Quiz Management → Question Bank → Template; fill rows in Excel/Sheets with exact headers; export UTF-8 CSV and preserve IDs across versions.
2. Admin uploads CSV, which is first staged, not immediately published; app shows columns/row previews, year/subject/topic coverage and errors with line numbers.
3. Server validates total limits, bytes/encoding, authorized admin, row security, fields, subject mapping, duplicate IDs and answer format, escaping, and question pool capacity.
4. Reject invalid rows and report precise errors; never hide partial failure as complete import. Require explicit import confirmation and status of inserted/updated/skipped rows.
5. If an import updates existing question IDs, require revision/version handling and preserve historical result integrity. Lock active attempts against mutation of their assigned questions.
6. Admin creates Standard quiz for exactly **one subject**, or Special quiz for **2+** eligible subjects, with selected Professional Year(s), required per-subject MCQ counts and topic filters. Preview availability including no-repeat estimates before publish.
7. Maintain `import_batch_id`, checksum, actor/time and change log for every import; idempotency makes re-upload safe.

## Example validation pseudocode

```text
CSV MIME/byte cap -> decode UTF-8 (accept BOM) -> parse RFC-compliant CSV
assert expected header set, report unknown columns without silent shifts
for each row:
  normalize IDs/year/subject/topic with controlled taxonomy
  assert non-empty stem and four distinct non-empty options
  assert correct_option in A-D
  assert question_id unique in batch and version workflow valid
  assert UTF-8 length bounds and safe output encoding
  collect status and faculty approval flag, never implicitly publish
show admin mapped preview, precise line errors, confirm transaction
```

## Question distribution example

Special event **illustrative only**: Professional Year 1, selected Pharmacognosy & Pharmaceutics, `per_subject_counts={Pharmacognosy:10, Pharmaceutics:10}`, one server-assigned set of 20 questions **shuffled together**. If the question bank holds only 5 from either group, preflight must block publish or ask admin to revise total / import more. Standard event **one subject** e.g. Pharmacognosy 20 questions per attempt; 3 attempts/day for a 1-day event would require at least 60 unique eligible question IDs for a user if every attempt must not repeat; over a longer event bank requirement grows.

## Security/privacy

Student responses must never contain `correct_option`, private explanations during exam or other question-bank answer keys. Admin CSV upload needs server role verification and rate limits; audit and soft-delete/revision; template/sample are intentionally safe demo rows and are not production content.
