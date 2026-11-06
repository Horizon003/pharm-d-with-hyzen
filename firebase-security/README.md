# Firebase security review

Observed live project `pharmawhisper-debd2` on2026-10-25 through an owner-authorized cloud-browser session. Project number975548206224 and Android app `com.hyzen.pharmd` / `1:975548206224:android:4d1d78ad7f7e5b8cd95c15` match the existing source configuration. Email/Password sign-in is enabled. The project shows the no-billing Spark plan. No live accounts, orders, messages, profiles, deployed permissions or billing settings were changed during this audit. The tested profile-only candidate was published in Console on 2026-10-25 after user confirmation. The selected live version matches tested source ignoring editor formatting whitespace; its initial NOT DEPLOYED comment is stale. No isolated live account write was made.

`deployed.2026-10-25.rules` is a whitespace-normalized transcription of the rules currently rendered by Firebase Console, not a raw server export. It preserves the observed policy for rollback/reference. Its last publication shown by Console was Jul15,2026. Never deploy the earlier speculative rules without diffing the live baseline.

## Rollout A — private profiles

`firestore.profile.rules` preserves the deployed legacy settings/inbox/verification contracts and adds only private `students/{uid}` access. Each authenticated student can get/create/update their own profile. Only the existing fixed administrator UID can get/list other profiles. Student identity/email/role/createdAt are immutable, role stays `student`, valid Professional Year is1–5, contact/academic types and sizes are bounded, unknown/password fields are rejected and timestamp writes use server time. Profile deletion remains disabled. Data is never public. Existing quiz namespaces remain default-denied.

The app's current DTO uses these fields and performs a get-before-create transaction; owner reads of a missing profile are intentionally allowed. Nullable/custom university/roll/photo fields and `avatar:<id>` values remain supported. Additional server-enforced data-size limits may require corrections to previously malformed records; no production profile data was enumerated or migrated.

This rule added access to a sensitive profile collection after explicit user confirmation. Review the Console publication and run isolated live account acceptance before relying on it in the APK. It does not enable quiz gameplay or create a paid service.

## Rollout B — public verification privacy

`firestore.commerce.rules` additionally restricts public verification creation to five bounded status fields with a random128-bit token and initial Pending/Unpaid state. It rejects customer/address/purchase/total payloads and forged initial paid/completed state. Only the fixed admin may replace/update records. These links are a status convenience, not authoritative proof of payment or of accepted orders; anonymous create rate-abuse still requires a trusted backend/App Check strategy.

**Do not publish rollout B until every active legacy website/admin writer has been migrated and tested.** Older clients currently send nested personal data. Enforcing the new shape prematurely would reject those writes and could break an old admin's multi-document transaction. Flutter checkout/admin projection fixes are included in the review overlay; admin writes replace public records so old PII does not survive a merge. They clean only records actually refreshed by that client. Existing public PII is not automatically scrubbed; any migration needs a reviewed plan and explicit authorization.

## Isolated tests

Run `npm ci --ignore-scripts` then `npm test`. The pinned test-only dependencies and lockfile are separate from the app. Firebase CLI is always passed `--project demo-hyzen-rules`; test environments use only `demo-hyzen-*` and require `FIRESTORE_EMULATOR_HOST=127.0.0.1:<port>`. There are no production credentials, aliases, deployments or live fixture writes. CI uses Node22 / Java21 and the dedicated Firebase review workflow. The current combined suite also starts the loopback Auth emulator for a real Auth-client/profile integration fixture; CI validates Node22/Java21. No production account is used.

Tests cover the actual old profile denial/public-verification weaknesses; owner/missing-profile access; anonymous/other-account/admin-claim denial; immutable fields/types/timestamps; old content/Shop compatibility; private quiz denial; and the separate strict verification/replacement contract. Fixtures are synthetic and contain no real student/order records.

## Remaining backend gate

A default-off private CSV import service and callable handler candidate now exists in `../quiz-backend`, covered by18 real Admin SDK transaction tests. It is not deployed or integrated into an in-app wizard. The trusted student quiz allocator/scoring/registration/duel backend remains absent. Firebase Cloud Functions can be emulated before deployment; deploying Functions requires a Blaze billing project, per https://firebase.google.com/docs/functions/get-started. No billing upgrade was authorized or performed. Dedicated staging, approved scoring/time/aborted-attempt/privacy/duel policy and live acceptance remain required. Read-only Console access does not grant a deployed backend or a tested release.

The latest tests also cover atomic receipt/inbox writes, concurrent receipt recovery, post-drain admin retry, and real Auth SDK owner/admin profile access. See docs/handoff/CHECKOUT_AND_IMPORT_RECOVERY.md and PR1 for the exact final run status.
