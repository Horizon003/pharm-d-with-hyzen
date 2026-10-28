# Checkout and private-import recovery follow-up

Date: 2026-10-25 (Asia/Karachi). Review branch `work/hyzen-phase-01`, draft PR https://github.com/Horizon003/pharm-d-with-hyzen/pull/1. No application/quiz deployment, billing change or live customer/profile mutation was performed. Final APK remains withheld until the remaining release gates are met.

## Checkout behavior

The original order payload, ID, verification token and purchased cart are saved in an account-scoped local outbox before any submission. Reopening checkout after app restart restores its original contact/address/items/totals, locks editing and retries the same reference. A malformed saved record blocks a replacement checkout instead of silently discarding uncertain state. Cart offers Resume saved checkout even after its visible items have been cleared.

Submission reads the receipt inside a Firestore transaction before creating the private inbox and minimal public receipt together. A matching existing receipt causes no write, including when the admin already drained the inbox or the shopper is the administrator. A failed/ambiguous transaction can recover only from a matching server-fetched order number and creation timestamp. Conflicting or unavailable receipts never claim success. This also handles create-only rules rejecting a losing concurrent transaction before SDK retry.

Acknowledgement is saved separately before local history/cart cleanup. Cleanup errors retain recovery state and cannot request a new order ID. History is visible in the current session even if its disk write fails. Purchased quantities are reconciled with the cart; one durable cart record holds both the remaining items and completion marker, preventing a repeated cleanup from consuming later additions. Account changes are checked before submission, cleanup and showing success.

Limits: this is device-local recovery, not a trusted stock/payment service or cross-device guarantee. Clearing app data loses its outbox. The receipt must be retained for retry protection; existing legacy policy still permits anonymous creation and admin deletion. Public receipts are not payment proof. Client stock checking does not reserve inventory. All active legacy writers and existing public-data remediation still precede strict commerce rule rollout.

## Auth and profile integration

An additional test uses the actual Firebase Auth client SDK against loopback Auth and Firestore emulators. Synthetic registration/login/logout, owner profile write/read, other-user read/list denial and the fixed-admin roster path are exercised together. The emulator-only Admin SDK creates a synthetic fixed-UID account; no production users, credentials or profile records are used. This supplements rule-context/widget tests; actual live-account/app acceptance remains separate.

## Import boundary and preview retention

Callable adapters explicitly require authenticated and App Check contexts, preserve verified identity, and map private errors to bounded diagnostics. Five handler tests cover these behaviors; they do not validate real Auth/App Check tokens or deployed IAM.

An undeployed hourly scheduled candidate reads at most 100 expired preview batches, rechecks each in a transaction and replaces only still-uncommitted expired question payloads with private metadata tombstones. Committed imports and current previews survive; repeated/overlapping cleanup is idempotent. Four real Admin SDK emulator tests exercise expiry, preservation, bounded concurrency and commit-before-cleanup races. The required composite index is included. Scheduling/index/IAM deployment, backlog monitoring and audit-metadata retention remain outstanding; cleanup is eventual, not an exact 15-minute deletion promise.

## Evidence and release gates

Backend handler/retention source6310107d passed46 tests in run40212661468. The added transactional Shop receipt case passed in run40213199669 after the test was aligned with the app's server-receipt fallback. Follow-up CI for the actual Auth integration and final Flutter source is linked in PR1; do not infer a completed run from this description of added tests. Local13 Python assembly/offline-CSV tests passed.

Still required: isolated live owner/admin acceptance; legacy commerce writer migration and existing-record remediation; approved backend hosting/billing and staging; real academic taxonomy; in-app Question Bank/revision workflow; trusted quiz allocation/scoring/ranking/registration/duels and policy decisions; physical Android camera/performance/accessibility tests; production assembly/signing/rollback and final release validation. Campus League gameplay and monetary features remain disabled/absent. Main remains unchanged.
