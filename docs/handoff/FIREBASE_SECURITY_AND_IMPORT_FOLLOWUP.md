# Firebase security and private CSV import follow-up

Date: 2026-10-25. Review branch `work/hyzen-phase-01`, draft PR https://github.com/Horizon003/pharm-d-with-hyzen/pull/1. App/privacy source commit `02a65ccee325e012ededca9d23ce2b38c35b4183`; backend candidate commit `6fc812008934f7da695c929fd9dfca6356707a98`. Main remains `e19bf01b63df7dffb419e900eb0fa13bc994b304`. This is a tested review candidate, not a production release.

## Observed live configuration

The user-authorized cloud-browser session reached the signed-in Firebase Console for `pharmawhisper-debd2`. Project number975548206224, Android package `com.hyzen.pharmd` and app ID `1:975548206224:android:4d1d78ad7f7e5b8cd95c15` match existing source configuration. No replacement Firebase config was needed. Email/Password authentication is enabled; Google app authentication is not enabled. The project shows Spark with no billing account. No Auth users, profile records or customer/order contents were enumerated for this audit.

The deployed Firestore rules, last publication shown as Jul15,2026 10:51AM, have no students match and therefore deny the app's profile access. They also allow anonymous verification get/create without a field schema. Existing source wrote customer/contact/purchase fields into that public-get collection. This is an observed policy/source privacy gap; no actual customer record was queried or disclosure incident established. `firebase-security/deployed.2026-10-25.rules` is a whitespace-normalized transcription of rendered Console rules, not a raw export.

## Prepared profile publication

`firebase-security/firestore.profile.rules` preserves observed settings, orders/messages inbox and verification behavior and adds private students access. Owners may get/create/update their own profile; the existing fixed administrator may get/list profiles. Unknown/password fields, student role escalation, identity/email/createdAt mutation and invalid sizes/types/timestamps are rejected. Delete is denied; quiz namespaces retain default deny. Missing-document owner get is intentionally supported for the real get-before-create transaction. Nullable university/roll/photo fields and avatar IDs remain supported.

On 2026-10-25 at the Console-displayed 6:06 PM, the user-approved profile candidate was published. Console shows a new Today rules version; its read-only text matches the tested repository candidate after removing editor formatting whitespace. The candidate blob SHA is `8f7fab6fa12494c4a68f6f783887b363990b6ae2`. A cropped screenshot of the published timeline was saved without account identity or admin UID. The rule source retains its pre-publication NOT DEPLOYED comment; that comment is stale, while the Console timeline and exact rule text establish the publication. Isolated live-account acceptance is still pending.

## Commerce source fix and separate rollout

The Flutter public verification projection now contains only orderNumber, status, payment, createdAt and trackingId. Values are bounded/validated; customer identity, address, items, totals, owner UID and unknown fields are excluded. The private order payload remains complete. Admin transactions share this projection and replace the public document instead of merging, removing old personal fields from records refreshed through the updated client.

`firestore.commerce.rules` is a separate stricter candidate: five-field allowlist, random128-bit token, initial pending/unpaid state and admin-only status changes. It is **not** the Console publication candidate. Active legacy website/admin writers must migrate before this rule can safely be enforced, or their transactions may fail. No old public documents were bulk scrubbed; no live order/payment/message was sent. Anonymous abuse/rate control and checkout submission/local-history retry idempotency still require trusted backend and staging acceptance. Public links do not establish authoritative payment or order acceptance.

## Private import backend candidate

`quiz-backend` now contains real Firebase Admin SDK transaction code and callable `previewQuizCsv` / `commitQuizCsv` handlers, default off and not deployed. Callable App Check and authentication, fixed server-configured admin UID allowlist, enabled private control and an owner-approved server-side taxonomy are required. Client role/admin flags and supplied taxonomy are ignored/rejected.

Preview validates bounded CSV, taxonomy, IDs, options/answers, unsafe markup/formulas and duplicate rows; it stores only private expiring batches and returns metadata. Commit binds actor/checksum/idempotency key, rechecks control/taxonomy/expiry inside one transaction, reads all target revisions before writing and creates immutable first revisions. Conflicts reject the whole batch. Same-key concurrent retries return one allowlisted summary; overlapping batches cannot partially import or overwrite. Every imported question remains draft even when CSV requests active. Questions/options/answers/explanations are never returned in preview/commit responses, including replay.

No actual curriculum was invented or seeded. No question-bank UI, revision editing/publication, student exam endpoint, allocator, scoring, rankings, registrations or duels was enabled. Full callable HTTP/Auth/App Check integration, deployed IAM, abuse controls and preview-retention cleanup remain open. The service tests exercise real Admin SDK/Firestore transactions against synthetic loopback demo projects, not deployed endpoints.

The current Spark project cannot deploy Cloud Functions without a Blaze billing decision; see the official deployment prerequisite at https://firebase.google.com/docs/functions/get-started. No billing upgrade, new project, terms acceptance or deployment occurred. Dedicated staging and actual taxonomy are required before integration. Scoring/tie/best-attempt, timezone/aborted-attempt, registration privacy and duel policies still need approval before gameplay activation.

## Verified checks

| Scope | Evidence | Result |
|---|---|---|
| App assembly / analyzer / Flutter | source02a65cce, run40193158029, job121168291117 |327 assembled files,133 overlay-owned paths; clean analysis9.6s;159 tests pass52s; capture completed |
| Android emulator | same run, job121169021687 |debug app/test APK builds and60 instrumentation tests pass |
| Rules + private import transactions | source6fc81200, run40193959441, job121170698679 |35 tests pass,0 fail,17.053s; Node22/Java21 |
| Local emulator | same35 tests with Node24/Java17 |35 pass; no production aliases/credentials |
| Source assembly / offline CSV utility | local rerun2026-10-25 |13 Python tests pass0.103s |

The35 emulator tests comprise17 security tests and18 private import tests. They cover baseline denial/exposure behavior, profile owner/admin boundaries, compatibility, answer-key namespace denial, strict verification shapes, server import authorization, validation, expiry, immutable atomic writes and concurrency/idempotency. Five additional Dart tests verify the public projection and private payload preservation. Emulator success does not prove physical-device or live-account acceptance.

## Rollback and next gates

The profile rule is now published. The previous deployed transcription is retained as a rollback reference; restoring it would revoke student profile access and requires review. No backend endpoint or commerce rule was deployed. Source changes remain isolated on the review branch. Do not remove phase07 wholesale to roll back just this privacy fix; revert only the four scoped source-overlay entries from02a65cce. The backend directory/workflow can be removed without touching live data while undeployed.

Next: isolated live-account acceptance; legacy commerce writer migration and reviewed existing-PII cleanup; staging/hosting/billing and real taxonomy; in-app import plus callable/IAM integration; gameplay policy/backend/UI work; physical phone and release/rollback acceptance. No monetary quiz capability was introduced. PR remains draft; no merge, signing, application release or quiz backend deployment occurred.

## Admin student access follow-up

The published students rule permits only the fixed administrator UID to list/get other student profiles. Earlier admin UI exposed only a `pw_users` website-student count and Shop/content views; there was no app student profile roster. Review source3b4e88ea adds `/admin/students` with a private read-only, server-fetched, 50-at-a-time roster and profile detail sheet. The route and repository both check administrator state; Firestore independently enforces the UID. No student write/delete action or password access is offered. Firebase Auth accounts without a `students/{uid}` record and legacy website `pw_users` entries do not appear in this roster.

The admin route/roster widget regression passes in the latest review run: source91ecc594 / run40198179439 assembled328 files with135 overlay-owned paths, analyzer clean (10.8s),159 Flutter tests and screen capture passed; debug application/native-test APKs built and all60 Android emulator tests passed. This is a development APK build inside CI, not a distributed production APK or live-admin login. No live student documents were read for this audit.
