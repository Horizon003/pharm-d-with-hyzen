# Offline quiz CSV preflight

This read-only developer/admin utility checks a UTF-8 question bank before any future staged server import. It does not import, publish, authenticate an admin, approve content, score an attempt or enable Campus League. Students receive no new question API or answer-key asset.

Run from the repository root:

```sh
python3 tools/quiz_csv_preflight.py /private/questions.csv --taxonomy /private/verified-taxonomy.json
python3 tools/quiz_csv_preflight.py /private/questions.csv --taxonomy /private/verified-taxonomy.json --existing-ids /private/current-question-ids.json
python3 -m unittest discover -s tools/tests -p 'test_quiz_csv_preflight.py' -v
```

Taxonomy is mandatory and must be supplied from the actual approved academic dataset. The JSON shape is `{"schema_version":1,"years":{"2":{"subjects":{"actual-subject-id":{"topics":["actual-topic-id"]}}}}}`. IDs in this shape are placeholders, not curriculum or invented repository records. No aliases, subject/year mapping or scoring rules are guessed. The existing-ID inventory is an optional JSON string list; conflicts block validity and require immutable revision review rather than overwrite.

Required CSV headers match the handoff's ten core columns; explanation/difficulty/status are optional. The blank and demonstration/draft files remain in docs/handoff/quiz_contract. This tool never silently activates their questions. Empty status is interpreted as draft for the report only; input bytes are unchanged. Active rows can pass syntax validation but are explicitly counted as requiring trusted-server approval.

Checks include 2MiB input and2000-row bounds, strict UTF-8/BOM, quoted multiline CSV, exact unique headers, per-row column counts, stable IDs/duplicates/revision conflicts, supplied year/subject/topic membership, required stem/four distinct options, A–D keys, allowed difficulty/status, length caps, HTML and spreadsheet-formula prefixes. Potentially legitimate text flagged by conservative checks must be reviewed; it is never silently rewritten. Reporting stops at100 errors. Error line numbers refer to the starting physical line of each CSV record, including quoted newlines.

Exit0 means local preflight passed; exit1 means CSV validation failed; exit2 means the input/taxonomy/inventory could not be safely read. JSON output contains counts, coverage, input checksum and line/field/error codes. It excludes stems, options, explanations and answer values. Error handling does not echo raw private input. No input file is modified and no network call occurs.

This is not a server authorization or publication gate. Actual backend authentication, malicious-upload rate limits, transactional audited/idempotent import, answer-key secrecy, immutable revisions, real taxonomy approval and scoring/time/duel policies still require Phase08–10 staging implementation and verification.
