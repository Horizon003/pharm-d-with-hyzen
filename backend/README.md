# Historical Cloud Functions implementation — do not deploy

The active free runtime is [`../push-worker/`](../push-worker/OWNER_SETUP.md).
Firebase must remain on **Spark**. Do not deploy `functions/index.js` or enable
Blaze, Cloud Scheduler or billing. The policy below describes historical source,
not the active global professional-year ranking service. The Worker combines all
colleges within professional years 1–5 and supports week, month and professional
total in Pakistan time. `functions/scoring.js` remains the shared tested policy.
The public `PUSH_API_BASE` supplies both study and notification APIs.

Status: source and pure scoring tests added; **NOT DEPLOYED**. No production
Firebase credentials or deployed rules were available in this workspace. The
existing `hyzen_flutter/firestore.rules.proposed` explicitly says deployed rules
are unknown. Do not overwrite them with this standalone emulator rules file.

## Policy and data

- `studyUsers/{uid}/events/{eventId}`: owner-readable offline personal intervals;
  immutable IDs, max 100 per upload, deduped transactionally. These client times
  NEVER contribute to competitive scoring.
- `campusMemberships/{uid}`: Admin SDK-managed verification, `campusId`, campus
  `timezone` (default Asia/Karachi), `academicYear`, privacy alias and `optOut`.
  Only `verified:true, optOut:false` members participate. The owner must verify
  an institution through their real administrative process; text in a student's
  self-editable profile is never verification.
- `studyUsers/{uid}/state/lease`: one active server lease/account. Foreground
  heartbeat every 15 seconds. Gaps above 30 seconds and clock reversal earn zero.
  This limits timestamp spoofing; it is NOT proof of human attention or immunity
  to automation. App Check/rate monitoring should be enabled and device tested
  before opening a competitive leaderboard.
- `verifiedSessions` and `verifiedDays`: server-only receipt-time aggregates.
  Ten-minute completed session bonus; 15-minute qualifying study day. The
  sub-30-second heartbeat interval crossing campus midnight is conservatively
  discarded, documented rather than credited to the wrong day.
- Campus score: +1/min cap 360/day, +2 per >=10min completion cap 5/day,
  +5 per consecutive >=15min day starting with day 2. Week starts Monday;
  semesters Jan–Jun and Jul–Dec in the verified campus timezone. Ties use
  scored minutes then UID. A campus must use one administrator-defined timezone.
- `campusLeaderboards/{campus}/periods/{week|month|semester}` publishes a generation
  only after all its entry batches finish. Old generations need a retention job
  before large-scale rollout. `readCampusBoard` checks current eligibility and
  opt-out for every returned row and paginates 30 at a time. Client reads/writes
  to raw leaderboard collections are denied. Existing caches are labelled offline.
- `setRankPrivacy` only changes alias/opt-out, never verification or points.
  Private reminders, task text and documents are not uploaded by this service.

## Repeatable checks

`cd functions && npm ci --ignore-scripts && npm test`

`functions/node_modules/.bin/firebase emulators:exec --project demo-hyzen-study --only firestore "cd functions && npm run test:rules"`

CI runs pure scoring and Firestore emulator access tests. Live multiple-account
integration, App Check, abuse load tests and deployment are separate release gates.

## Historical deployment notes (superseded; not executable instructions)

1. Obtain the deployed Firestore rules and backup; merge ONLY the three new match
   blocks from `study.rules`, preserving existing app/admin permissions. Review
   existing catch-all allow rules: a broad allow would override these denials.
2. Do not deploy this historical Functions runtime. Use the free Worker/D1
   deployment described in the owner guide. Keep Firebase on Spark.
3. Run emulator security tests, seed consenting verified test memberships through
   Admin SDK, and verify auth, multi-account isolation, privacy, concurrency,
   partial acknowledgements and generation pagination against a staging project.
4. Build with the owner-selected `PUSH_API_BASE` Worker URL. Do not set
   `STUDY_API_BASE` to undeployed Cloud Functions. No fabricated ranks are displayed.
5. Roll back by rebuilding without STUDY_API_BASE, disabling the schedule and
   callable functions, retaining private event data and the preceding rules backup.

Remaining architectural limits: local events still use versioned preferences,
not a migrated Hive session database; goal/task multi-device conflict resolution
and downloading/reconciling personal history onto a fresh device are not finished.
Do not label these as complete cloud sync or production-ready competitive ranking.
