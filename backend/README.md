# Firebase-native study sync (Spark)

The Flutter app uses **Firebase Auth + direct Firestore**, in the existing
`pharmawhisper-debd2` project. Study sync does not use Cloudflare, `PUSH_API_BASE`,
Cloud Functions, Cloud Scheduler or a Blaze plan. Do not deploy the historical
`functions/index.js`; its scoring helpers/tests are retained for policy history.
The existing OneSignal sender and legacy study endpoints remain available to old
APKs. Their production records are not deleted or silently converted to trusted
Firebase competitive scores.

## Data and trust

- `studyUsers/{uid}/eventBatches/{firstEventId}`: immutable personal-history
  batches, up to 100 intervals. Lost responses acknowledge only IDs actually in
  the committed batch; unsent intervals remain queued. Personal timestamps do
  not award competitive points. Local history is uploaded once during upgrade.
- `state/activity`: one active file session/account. Every interval is bounded by
  two committed **server timestamps**. The next pulse settles the preceding
  interval; points lag roughly one 15-second heartbeat. Gaps over 30 seconds,
  paused intervals and intervals crossing Pakistan midnight earn zero. File
  close pauses immediately; the uncredited 30-second UI grace then closes the
  session. No manual Start button is required.
- `state/wallet`: daily claim 100; each seventh consecutive claim +200; milestones
  5/7/14/30/60/100 +50 once each. Rules validate the server date and exact deltas.
  Study points are floor(confirmed milliseconds × 100 / 3,600,000).
- `verifiedDays` and private `state/rank_1`…`rank_5`: server-validated credit.
  Professional score +1/min, cap 360/day; +2 per completed 10-minute session, cap
  five/day; +5 for a consecutive qualifying 15-minute day. Week starts Monday;
  month and professional-total are supported. These are distinct from wallet points.
- `campusMemberships/{uid}`: admin-verified professional year; student-selected
  alias and opt-out. A one-time Firebase ranking-consent marker prevents an old
  D1-only opt-out preference becoming an automatic Firebase opt-in. Confirm the
  existing ranking privacy control once; no points/history are deleted. Private
  profile text cannot verify an account.
- `professionalRanks/{uid}`: only opted-in verified students, projected exactly
  from their private year ledger. Board sorted by points/minutes/UID, pages of30.
  Admin verification/year changes **must delete this public row in the same
  atomic write**; the native Admin Data Manager provides that action. Admin SDK
  or Firebase Console changes bypass rules, so use the same paired invalidation.
- `calendar/{id}`: private events and color. Device reminders remain scheduled
  locally; documents/PDF contents are not uploaded by this service.

Confirmed snapshots include metadata changes so local optimistic writes cannot
silently drop their eventual server confirmation. Polling is reserved for retry
and period rollover. Free Firestore daily quotas still apply; security against
fabricated timestamps does not prove human attention or prevent automated clients.

## Verification

From the repository root:

```sh
(cd backend/functions && npm ci --ignore-scripts)
node --test backend/tests/merge-firebase-rules.test.cjs
backend/functions/node_modules/.bin/firebase emulators:exec --config backend/firebase-native.json --project demo-hyzen-native --only firestore 'node --test backend/tests/firebase-native.test.cjs'
```

The checked-in full rules file is **an emulator candidate, not an authorized
replacement for current production rules**. Twelve rule tests and an opt-in real Flutter SDK/admin round trip cover legitimate credit,
forgery, duplicate/concurrent claims, bonuses, privacy, pauses/gaps and revocation.

## Deploy into the existing project

The reviewable workflow is `.github/workflows/firebase-native-sync.yml`.
Add a Firebase service-account JSON directly to the repository Actions secret
**`FIREBASE_SERVICE_ACCOUNT`**, not in chat or source control. It needs permission
to read/write Firebase Rules and create/read Firestore composite indexes in this
project. Existing release-signing secrets cannot deploy Firebase.

Run the workflow on `work/monochrome-motion-1.5.5` with `deploy=true`. It:

1. Tests the local candidate with the emulator.
2. Reads and backs up the CURRENT deployed rules through the Rules API.
3. Replaces only the canonical membership block and appends the marked study
   fragment; all unrelated settings/profile/admin policy stays intact.
4. Uploads the old rules/release and proposed merge as an Actions artifact.
5. Runs the same adversarial tests against that actual merge. Broad existing
   allow rules fail the tests and prevent deployment.
6. Creates only missing ranking indexes through the Firestore API and waits for
   them. It never deletes existing indexes.
7. Deploys only the tested Firestore rules merge. No Functions, billing or other
   production backend settings change.

After deployment, test two real consenting accounts: open/close a file, wait for
confirmed points, claim twice, verify the board and opt-out, create/delete a
calendar event, reinstall/update and check history. Emulator evidence alone does
not establish production sync. Historical D1 verified scores need a separate
trusted admin export/migration if they are to be carried forward.

Rollback uses the saved previous rules and release APK; retain Firestore data.
Goals/tasks that were already device-local are not claimed as multi-device sync.


## Current activation status

Production deployment passed in run [44441672939](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44441672939).
Live authenticated checks passed in run [44442506765](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44442506765), including all ranking query/count indexes and opt-out. Temporary QA data was removed.
The existing 1.5.10+19 APK needs no rebuild.

Publication uses the standard Firebase Rules REST API: create an immutable,
server-compiled ruleset, confirm the active release still matches the backup,
update the release, then read it back to verify. Emulator security tests remain
mandatory. The CLI's additional `projects:test` permission is not required by
this publication method. Unit tests ensure compiler failures and concurrent edits
never update the active release.
