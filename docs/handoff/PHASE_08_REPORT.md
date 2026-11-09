# Phase08 — private CSV backend candidate and remaining integration

Status PARTIAL. Source6fc812008934f7da695c929fd9dfca6356707a98 adds actual Firebase Admin SDK import transactions and two Firebase callable handlers. These are default off, tested in a local/demo emulator, not deployed and not connected to an in-app Question Bank. The preserved blank/demo CSV, schema/guide and offline preflight remain review resources; no demo curriculum or questions are seeded into production.

## Implemented server boundary

`quiz-backend/index.mjs` exposes previewQuizCsv and commitQuizCsv through callable authentication and enforced App Check. `import-service.mjs` requires a fixed server-configured admin UID allowlist, enabled private import control and owner-approved server-stored real taxonomy/version. Missing configuration denies access. Client claims/role fields or supplied taxonomy cannot grant authorization.

Bounded CSV validation covers UTF-8/BOM/quoted multiline parsing, required/duplicate/unknown headers, safe IDs, duplicate questions, real year/subject/topic membership, options/answers/lengths and unsafe formula/HTML cells. Diagnostics contain only line/field/reason, never question text or answers. Preview creates a private expiring batch, actor/checksum/taxonomy digest and metadata-only response. No publication occurs on upload.

Confirmation binds checksum and idempotency key. A real Firestore transaction rechecks actor, expiry, feature control and taxonomy, reads all target revisions before writes, then atomically creates immutable first revisions and commit audit. Existing IDs reject the whole batch for separate revision review; no partial commit or overwrite. Same-key concurrent retry returns one safe summary, different-key replay is rejected and overlapping batches cannot partially import. Replay also reconstructs an allowlisted result rather than echoing stored private fields. Every imported record is draft even if CSV requests active.

Private namespaces are quiz_control, quiz_import_batches and quiz_question_revisions. Observed/profile-candidate rules default-deny all client access to these collections; the Admin SDK bypasses rules and independently enforces service authorization. No student question/result/attempt API exists. Public DTOs must remain explicit allowlists when future endpoints are added.

## Evidence and limits

Dedicated run https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40193959441 passes35 tests on Node22/Java21:17 rules and18 import-service cases using real Admin SDK transactions against synthetic loopback demo projects. This includes unauthorized/default-off/taxonomy/validation denial, immutable all-or-nothing writes, expiry, stale-taxonomy detection and concurrent retry/conflict tests. The same35 tests pass locally;13 Python assembly/offline-CSV regressions also pass. Callable module import succeeds. Full callable HTTP/Auth/App Check behavior and deployed IAM are not yet integration-tested.

No actual academic taxonomy has been invented or configured. First revision import is supported; revision editing/publication, in-app templates/wizard/history UI, preview-retention cleanup, abuse/rate monitoring and staged deployment remain. Expired previews cannot commit but are not automatically deleted. No live Firestore data was queried or written by the tests.

## Deployment and later phases

Firebase Console access and deployed-rule inspection are now available; the existing source config matches the actual project. Owner-only profile rules were published after user confirmation; live account acceptance remains. The current project is Spark; Cloud Functions deployment requires a Blaze hosting/billing decision (https://firebase.google.com/docs/functions/get-started). No billing upgrade, new project, terms acceptance, endpoint deployment or question publication was performed. Dedicated staging is required before live integration.

Phase09/10 remain disabled/unimplemented: trusted allocator, private answer keys/assignments, atomic start/submit, server deadlines, no-repeat history, scoring/rankings, Special registrations and duels. Actual scoring/penalty/tie/best-attempt, daily timezone/aborted-attempt, eligibility/dispute and privacy/duel policies still need approval. No fee/payment/wallet/prize feature is introduced.

G1–G4/G6 are PARTIAL or BLOCKED rather than complete: a tested import foundation does not satisfy a full authenticated in-app import/publication/exam acceptance gate. No monetary capability exposed remains a source-scope constraint, not certification. Undeployed backend source can be removed without a live migration. See FIREBASE_SECURITY_AND_IMPORT_FOLLOWUP.md and REMAINING_EXECUTION_QUEUE.md for exact state and next gates.
