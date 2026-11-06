# Phase 06 — Home, profile, settings and notifications

Branch work/hyzen-phase-01, draft PR https://github.com/Horizon003/pharm-d-with-hyzen/pull/1. Implementation checkpoint 7e187372b3ff41eb2bacfa36c5975b2ae9966344. Overlay updates_phase_06.json follows updates_camera.json. Main/production unchanged.

## Observed services and delivered behavior

Existing Riverpod profile/auth providers, real StudentProfile fields, existing academic-year route, password-reset form, SharedPreferences and announcement/siteFullScreenNotice sources are retained. No unsupported username change, app lock or fabricated notification service is exposed.

Home adds real Scan notes, Offline library and My study year quick actions while preserving its approved Gen Z artwork, actual resource counts and recent files. Profile places the avatar above a centered name in a Slate panel with Personal, Academic and Security tabs. Details remain private; email/role/UID are not rewritten. Existing profile editor, admin access, promotions, orders, About/Contact and logout remain reachable.

Settings adds a searchable preferences list, tall workspace card, Edit profile/My year actions and wrapping appearance controls. Existing palette, Light/Dark/System, preview-cache cleanup and notification settings remain functional. Signed-in password reset opens the existing prefilled reset form; tests send no email.

Notifications uses actual categories only when present in stored/source data. Public announcements default to Announcements; no order-feed data is invented. Read, archive, remove and Undo persist only after a successful local write. Versioned account-scoped notification envelopes preserve legacy caches for rollback. The last100 dismissal tombstones stop those active announcements resurfacing after restart; older evicted tombstones may allow an old still-active notice to reappear. The local inbox/archive also retains up to100 items. A serialized mutation queue and owner/generation checks prevent stale account actions or Undo from changing the new account. Archive is local to the device, not a server-wide read-state promise.

Changed application paths: lib/features/home/presentation/home_screen.dart, lib/features/profile/presentation/profile_screens.dart, lib/features/notifications/notifications_screen.dart, lib/app/router.dart, test/navigation_test.dart and test/notification_account_test.dart (exact overlay keys are authoritative).

## Evidence

Run https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40162938847: analyzer clean in 10.4s; all 134 Dart tests passed in 43s; screenshot capture passed. New tests cover legacy cache/archive restart, active-notice dismissal and Undo, account switching, Settings search/My year/Security navigation and notification categories/archive. Password reset assertion checks the actual form and prefilled email, because imperative GoRouter push need not change browser URL.

Artifact 12587296628, SHA256 7e9c7581eca0cf8211ed50bcb312f13da32148f4dcef3580a1538bd0f875a87e, was downloaded and verified. Light Settings, dark Profile and light Home screenshots were inspected. Review found low contrast in the workspace badge on the fixed Slate panel; explicit foreground/background colors replace theme-adaptive pill colors in the follow-up. Sourcef2c98599/run40164302166 passed clean analysis and137 tests; the corrected dark Profile badge and dark Settings screenshot were inspected in artifact12587423901.

Fixtures use synthetic student details, not a real account. No production profile was edited, email sent or customer record queried. Live authentication/rules, physical accessibility and account-save acceptance remain open. The same run passed all 36 Android native tests including the Material camera polish; this does not imply physical acceptance.

## Rollback and gate

Remove phase07 first if present, then phase06 from both review assembly loops; removing camera also requires dependent phase06/07 routes be reverted together. Preserve all user files and notification v2 state. Legacy caches are untouched; an old client can show its older read state. No backend migration is needed. Software checks passed at the checkpoint, but live-account/device acceptance is partial.
