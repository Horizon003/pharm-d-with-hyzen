# Independent source/CSV preparation

Tools are repository utilities, not enabled student features or deployed server APIs. No external package/tool installation, production signing or backend import was performed.

## Quiz CSV preflight

Source714d09eb / run40175886191 passed7 standard-library Python tests. tools/quiz_csv_preflight.py checks strict UTF-8/BOM and quoted multiline CSV, limits/header/row shape, stable duplicate/existing IDs, required supplied year/subject/topic taxonomy, four distinct options/A–D keys, length/difficulty/status and HTML/formula risks. Error reports use physical start line/field/code, counts, coverage and input checksum; they do not echo question text/options/explanations or answer values. Inputs remain unchanged. Active syntax-valid rows are explicitly marked as requiring trusted-server approval; no questions are published and no admin authorization is claimed. Blank/sample handoff contracts remain review files, not a production curriculum.

Actual taxonomy and trusted staged backend are still required. The tool has no default sample mappings or aliases. Scoring, idempotent server import, rate limits/roles, historical revisions, attempt secrecy/limits, private registration and duels are still Phase08–10 blockers.

## Source assembly

Source67e96c33 / run40176797249 passed13 total Python tests and assembled the actual repository into321 files with123 total overlay-owned paths (legacy plus review overlays), without building/deploying. Six assembly regressions cover reproducible order/binary hashes, existing-output protection, traversal/signing/wrong-value rejection, ZIP symlinks, source symlinks/output overlap and review-only debug test configuration. The source-tools CI artifact contains the SHA-256 assembly manifest, not private source contents.

tools/assemble_review.py applies the observed base/root/legacy/phase/camera/assets order and verifies final overlay hashes. Both isolated app-review jobs now consume this verified assembler; the native job asks for debug instrumentation only. Review Gradle cache keys use assembled dependency files, and superseded review runs share a cancellation group. Production release workflow and signing guards remain unchanged.

A fresh output directory is mandatory; existing files are never overwritten. No deploy, install or build occurs. See tools/ASSEMBLE_REVIEW.md and tools/QUIZ_CSV_PREFLIGHT.md for exact invocation and limits. Assembly success is not Android/device/backend acceptance; final app regression evidence is in NATIVE_DOCUMENT_HARDENING.md.
