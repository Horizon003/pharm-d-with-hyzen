# Hyzen push deployment and professional rankings

## Actual state

Worker `hyzen-onesignal-sender` uploaded to the connected Cloudflare account.
D1 `hyzen-push` exists and schema.sql was applied. No paid plan was enabled.
OneSignal App ID is c8344ed8-429a-4c09-8f74-6cc120918dda. The connected OneSignal
app listing sees it, but credential-status API returned 401. Uploaded FCM credentials
were not changed. API acceptance is not evidence of phone delivery.

## Verified configuration (8 November 2026)

The public endpoint is `https://hyzen-onesignal-sender.harisaslam003.workers.dev`.
Its unauthenticated requests correctly return HTTP 401. Cloudflare settings show
`ONESIGNAL_REST_API_KEY` as an encrypted `secret_text` binding, alongside the
expected D1/project/app/admin bindings. The secret value was not read or logged.
Do not repeat account initialization or replace the existing secret.

Production Firestore access is currently blocked by Google sign-in. No deployed
rules have been read, backed up, modified or published. To finish the safe merge,
the owner must provide the **current Firestore Rules text** (not credentials), or
authorize Firebase console sign-in. The collection block below is a candidate
patch, not proof of a safe merge against unseen production rules. Firestore allow
rules are additive: an existing recursive wildcard allow can override a narrow
deny. Review every overlapping match before publishing. Never deploy
`backend/study.rules` as the whole production policy.

Fresh release CI requires `HYZEN_PUSH_API_BASE` to equal that public URL before
building. Signed APK provenance records the source commit and URL; signing still
uses only the existing production certificate. Production rollout requires owner
approval after the automated gates and real Android checks below.

## Setup reference (completed steps do not need repeating)

1. Open https://dash.cloudflare.com/?to=/:account/workers/workers-and-pages once.
   Cloudflare reported that this account has no workers.dev subdomain. Complete
   that free initialization. Open `hyzen-onesignal-sender` and enable its workers.dev
   address. Record the HTTPS URL.
2. OneSignal → this app → Settings → Keys & IDs → App API Key. Copy it directly
   into Cloudflare → hyzen-onesignal-sender → Settings → Variables and Secrets:
   name `ONESIGNAL_REST_API_KEY`, type **Secret**. Deploy the variable change.
   Do not paste it into chat, GitHub, Flutter, Pages or a source file.
3. Firebase → Firestore → Rules: back up the current deployed rules. In the existing
   `match /databases/{database}/documents`, merge the membership block below.
   Replace any existing block for this exact collection rather than adding an
   overlapping broad allow. Preserve all unrelated app/admin rules.

```rules
function hyzenAdmin() {
  return request.auth != null &&
    request.auth.uid == 'Vv6HtZjmUvfVACzvuyL2pFx5HR33';
}
match /campusMemberships/{uid} {
  allow get: if hyzenAdmin() || (request.auth != null && request.auth.uid == uid);
  allow list: if hyzenAdmin();
  allow create, update: if hyzenAdmin()
    && request.resource.data.verified is bool
    && request.resource.data.academicYear is int
    && request.resource.data.academicYear >= 1
    && request.resource.data.academicYear <= 5;
  allow delete: if hyzenAdmin();
}
```

4. Populate administrator-verified records in `campusMemberships/{Firebase UID}`:
   `verified: true`, `academicYear: 1..5`, `campusId: canonical college ID`,
   `alias: display alias`, `optOut: false` for consenting rank participants,
   `pushOptOut: false`. Students cannot self-verify or change these fields. The
   collection name is retained for migration compatibility; ranking groups are
   **all colleges within the same academicYear**. College is only a push filter.
5. Build Flutter with `--dart-define=PUSH_API_BASE=https://YOUR_WORKER.workers.dev`.
   For GitHub builds: Repository → Settings → Secrets and variables → Actions →
   **Variables** → create `HYZEN_PUSH_API_BASE` with that public HTTPS Worker URL.
   Then Actions → **OneSignal and professional rank verification** → Run workflow
   on `feat/onesignal-global-professional`. It builds the real Web/debug app and an
   owner-signed APK after checks. Pages also reads this variable after an approved
   merge. An empty variable produces an explicitly unconfigured test APK; a rebuild
   is required after setting the URL. Do not publish that test build as production.
   The same URL supplies the free study sync and ranking API. Do not set the old
   `STUDY_API_BASE` to undeployed Cloud Functions. Admin → Push Notification Center
   → reload audiences synchronizes the verified ranking roster, including removals.
   Without the URL the Admin Center shows an explicit configuration error and the
   existing inbox remains usable. Firebase stays Spark. Do not deploy the old
   experimental FCM Worker or enable Firebase Blaze.
6. On an Android device with Play Services: sign in, open Notifications → push
   preferences → Enable, grant permission. Confirm a real OneSignal subscription
   and matching Firebase UID external_id in OneSignal. Send to a verified test
   audience from Admin → Push Notification Center. Check foreground/background/
   terminated, click routing, account switching, offline inbox and repeated retries.
   An offline tap retains only its message ID (up to 24 hours) and retries on
   sign-in/app resume. The server must authorize that ID before navigation; an
   old notification can be checked even when outside the newest 100 inbox rows.
   Preserve the same message ID on retry. History says accepted, never delivered,
   until separate delivery/device evidence exists.

## Explicit limits and release gates

- Remote scheduled sending is disabled. Local task, opt-in daily goal (6 PM) and
  opt-in streak (8 PM) reminders use the existing Android notification plugin.
  Goal nudges cover a rolling week, refreshed on app resume; streak alerts cover
  only the next known risk day. Completed goals/qualifying study cancel today's
  relevant alert. Logout cancels account-scoped alarms. These require closed-app/offline/reboot
  testing on a real device; Firebase or OneSignal does not prove local scheduling.
- OneSignal's current official identity-verification documentation says Flutter
  cannot supply the verification JWT. Do not turn that dashboard toggle on for this
  Flutter SDK. Firebase UID login maps identities but is not impersonation-proof.
  Only non-sensitive announcement content should be sent until a supported identity
  verification integration is completed. No emails, phone numbers, private notes or
  health data are mapped as tags.
- All, college and professional audiences are selected from server-read verified
  records, not editable OneSignal tags. The sender is bounded to 3,000 profiles.
  Free Firebase/Worker/D1 quotas still apply. No automatic paid upgrade is enabled.
  The sender and roster use batched database calls; personal-history batches of
  100 events use two D1 requests rather than exceeding the free per-request limit.
- New material/rank/update/task types are admin-composed sends. Automatic backend
  content/rank/update event broadcasts are not installed. No nonfunctional trigger
  UI has been added.
- The free D1 runtime implements study sync, server-receipt leases, professional
  ranking and privacy. Weekly/monthly/professional-total SQL scores are regression
  tested against the shared policy. Professional history stays separate. D1
  transactions/version checks prevent concurrent heartbeat double credit.
  Immutable, atomically published one-minute snapshots keep pagination stable while
  other students study; roster/privacy changes invalidate the snapshot immediately.
  Students' own verified Firestore membership is rechecked before each pulse/board
  call. Other students' roster revocations/removals propagate when the admin reloads
  audiences; refresh this after roster edits. Offline events never earn rank points.
  This runtime is uploaded, but public access/owner rules and live ranking validation
  remain blocked by the setup above. The old Cloud Functions implementation remains
  **not deployed**; do not deploy it or enable Blaze.
- Do not merge/publish Pages or a production release until relevant CI and real
  Android delivery pass. Production APK must use the existing owner signing secrets
  and existing certificate fingerprint. No replacement signing key is permitted.

## Rollback

Keep PR #10 unmerged to preserve main. Disable the new Worker if needed; retain
the D1 send history. Restore the backed-up membership rules if reverting the
membership policy. No existing Firestore data or releases were deleted.
