# PHARM D WITH HYZEN — COMPLETE WORK CHAT FIX & RELEASE HANDOFF

> **Purpose:** Paste this *entire* file into ChatGPT Work/Codex and attach **`Hyzen App Creation(2).zip`** in that same Work conversation. The ZIP has the original UI references, including the six real landscapes. This document is an execution brief for completing the real Flutter app—not an invitation to make another HTML mockup.
>
> **User instruction:** **Complete all feasible missing work in the existing GitHub repository; compare every relevant screen to the supplied originals; fix regressions; build, test, and merge/deploy only when verified. Do not claim untested functionality works.** Continue from the existing PR instead of rewriting the app.

## 0. Repository, exact state, and non-negotiable setup

- GitHub repository: **`https://github.com/Horizon003/pharm-d-with-hyzen`**
- Flutter application root: **`hyzen_flutter/`** (not repository root)
- Current published app: **`https://horizon003.github.io/pharm-d-with-hyzen/`**
- Latest working feature branch to **continue**, not discard: **`feat/hyzen-original-design-completion`**
- Open **draft** pull request: **[#9 — Match original Hyzen UI reference and complete study functionality](https://github.com/Horizon003/pharm-d-with-hyzen/pull/9)**
- `main` currently has earlier PR #8 with limited locally persisted Study Time, basic Goals/Streak/Tasks and in-app reminders; PR #8 is **not** the complete approved specification.
- **Do not treat** `hyzen_flutter/web/new-features-preview.html` or any static/standalone interactive HTML as the actual Flutter app preview.
- Uploaded reference **`Hyzen App Creation(2).zip`** contains **14 genuine PNG images**. The previous written source-of-truth is **`Hyzen_Design_Implementation_Prompt.md`** / **`PHARM_D_WITH_HYZEN_MASTER_PROMPT.md`**. There is also a branch audit: `hyzen_flutter/docs/ORIGINAL_ZIP_REQUIREMENTS_AUDIT.md`.
- Original six landscapes have **already been compressed to WebP** and committed on PR #9 under `hyzen_flutter/assets/home_backgrounds/`. Preserve them and use those files, not generated/replacement art.
- **Most recent verified CI observation (Nov 7, 2026):** analyzer passed, full Flutter widget tests **failed** on branch; Android/Web checks have changed as runs progressed. Re-query **latest** GitHub Actions jobs/logs instead of assuming any earlier status. PR #9 was still **draft and unmerged** when this handoff was written. The latest observed run was **`42352734256`**, but subsequent commits/runs may supersede it.
- Preserve existing PDFs, scanner, Office Workspace, downloads, user accounts, Firebase integration, settings, and original branding. No destructive migration and no accidental data resets.

**Do this first:** Inspect the **current** `main`, PR #9 head, its changed files and latest CI logs. Check out the PR #9 branch, read relevant Dart/Kotlin/manifest/pubspec/Firestore files, and inventory the contents of the attached ZIP. Create a specific implementation checklist tied to the original screenshots. Do not start a new isolated preview project.

---

## 1. Ground-truth ZIP inventory — compare every original screenshot

The following PNGs inside `Hyzen App Creation/` are the **visual specification**. The artwork is a reference for native Flutter widgets, **never** a full-screen raster with invisible tap targets.

| Exact ZIP file | Required comparison / reconstruction |
|---|---|
| `homescreen light mode.png` | Primary, authoritative light Home screen |
| `1E9AFF89-3DE6-4E2A-BEF9-D6E84B27ABDA.png` | Alternate light Home composition; reconcile small variant differences with primary |
| `home screen dark mode.png` | True-black Home design, white text, restrained blue accents, **no glow** |
| `Goal section screen.png` | Full Study Goals page primary layout |
| `goal section screen with reminder and task form.png` | Extended Goals sections, **Add Task** and **Add Reminder** bottom-sheet designs |
| `streak screen.png` | Study Streak page: hero, weekly day checks, history, breaks, achievements |
| `campus rank screen.png` | Campus Rank page: verified campus, period filter, rank/leaderboard/details |
| `time background for homescreen/how it will look.png` | **Timing and composition guide**, **not** an individual runtime background |
| `time background for homescreen/early morning.png` | Early Morning original mountain landscape |
| `time background for homescreen/late morning.png` | Late Morning original mountain landscape |
| `time background for homescreen/afternoon.png` | Afternoon original mountain landscape |
| `time background for homescreen/late afternoon.png` | Late Afternoon original mountain landscape |
| `time background for homescreen/evening.png` | Evening original mountain landscape |
| `time background for homescreen/night.png` | Night original mountain landscape |

**REQUIRED visual QA:** Render actual Flutter screenshots of each relevant page at **320dp, 360dp, a standard Android phone, and large accessibility text**; light/dark Home; all six time phases; both form sheets. Compare **side by side** with supplied PNGs, iterating until layout, card hierarchy, typographic scale, spacing, borders, icons, blue/white palette, artwork, and shadows are as close as responsive native UI permits. Include a screenshot comparison report in the PR. Do not describe a screen as “exact” solely because similar words exist on it.

---

## 2. What PR #9 already contains versus what remains

**These are existence observations, NOT claims of finished behavior. Inspect them before changing anything:**

| Area | Present on PR #9 (partially) | Unfinished / requires validation |
|---|---|---|
| Original six landscape assets | Six compressed WebPs in `assets/home_backgrounds/`, declared in pubspec | Verify matching originals, sharp rendering, runtime decoding, size, phase transition and proper cropping |
| Time-adaptive Home | `lib/features/home/presentation/home_time_artwork.dart`, `home_dashboard_top.dart` | Fix phase refresh, exact screenshot composition, theme independence, accessibility, scrolling and reduced motion |
| Home page | `lib/features/home/presentation/home_screen.dart` rebuilt in part | Test and adjust avatar/greeting/study cards/hero/search/announcement/Quick Access/compact tools/recents, all navigation |
| Time tracking | `lib/features/study_progress/study_tracker.dart` | Robust real sessions, inactivity, monotonic elapsed time, midnight split, stop, offline durable outbox, server validation |
| Goals UI | `study_goals_screen.dart` | Screenshot accuracy, all form controls, edit flows, recurrence/advanced reminders, insights and tests |
| Streak UI | `study_streak_screen.dart` | Exact layout and accurate full history, achievements, gap calculations, 15-min rule, tests |
| Rank UI | `campus_rank_screen.dart` | Verified campus, actual ranking data, server scoring and Firestore security; **never fake leaderboard data** |
| Native notification scheduling | `study_notifications.dart`, manifest and gradle changes | Android 13+/14+ permissions, closed-app delivery, reboot, recurrences, quiet hours, snooze, deep-links, OS tests |
| Routes | `/study-goals`, `/study-streak`, `/campus-rank`, `/study-progress` wired | Navigation/auth and correct Home cards, deep-links, back button, no shell duplication |
| CI and release | GitHub Actions checks exist | **Full Flutter tests still failing**; regression fixes, real Android build, actual Web deploy unverified |
| Scanner/Office/Settings | Mostly existing app code | Re-audit all original MD requirements in §11 below; do not mark as complete on assumption |

**Never replace working app code with a static screenshot or silently omit a requirement because a UI placeholder exists.**

---

## 3. FIRST BLOCKER — make PR #9 compile and all existing tests pass

**Do this before merging or claiming the new build is live.**

1. Check the **latest** PR #9 GitHub Actions job logs (not just checkboxes or a stale run). Run `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` from `hyzen_flutter/`.
2. Earlier fixed issues included unmatched brackets in the Campus Rank/Goals Dart code. Verify none remain after subsequent edits.
3. A recent run confirmed analyzer success but **test failures**. Prior logs showed failures in `hyzen_flutter/test/navigation_test.dart`, including:
   - `HOME-09/15/16 real persisted download and recent providers feed Home`: expected `1 New` / `1 Saved` badge texts and genuine recent file; ensure cards reflect real persisted states and labels appear without overflow.
   - `HOME-06/13/14/16 responsive Home supports long content and reduced motion`: `RenderFlex overflow` on narrow 320dp devices / 2× text scaling, including Home compact tool row and header. Fix responsive constraints/scrolling or wrapping without hiding content.
   - `narrow phone layouts and large text remain usable`: no overflow anywhere in app navigation.
   - `reference Home hero and positioned profile fit a 360px phone`: keep a stable semantic/Widget key (e.g. `home-hero-art`), correct left avatar placement and other Home section labels.
   - Re-query newest logs; exact failures may have changed since these observations.
4. Do not delete/skip/relax existing tests just to obtain green CI. Only update a test when an **approved design change** genuinely changes the expected behavior; keep equivalent or stronger coverage.
5. Test no leaked timers/pending timers on widget dispose, especially time-phase periodic refresh and local reminder scheduler; use injectable clock, fake notification plugin/test hooks if necessary.
6. Keep scanner Android native compilation and Office test suite green. Ensure new dependencies do not break Gradle plugin/desugaring configuration.
7. Once green, do **not** immediately merge unless sections below are either implemented/tested or explicitly blocked with defensible evidence and user approval. PR #9 is a comprehensive feature task, not only a CI repair.

---

## 4. HOME SCREEN — recreate the approved light and dark references

### Visual structure and ordering

- Very compact **panda/photo avatar on upper left**, time-sensitive greeting and `Welcome back, [real first name] 👋`, notification bell at right with unread badge. Use actual profile name, never hardcode screenshot example names. Improve photo upload with proper **circular crop, drag and zoom preview** (keep image unmodified until Save).
- Froste​d/soft light blue-and-white **Study Time** card below header: circular study/book icon or ring, real elapsed time, real daily target, accurately computed progress percentage and bar, compact insights action. **Dark:** true black page, dark charcoal cards and white text, no neon/glow.
- **Three separate equal clickable stat pills:** Study Streak, Campus Rank, This Week. Wire to `/study-streak`, `/campus-rank`, `/study-goals` or accurate progress destination.
- Wide **mountain hero** with exactly the appropriate supplied landscape, `Continue to Study` CTA and real degree/professional year selector (from profile; do not hardcode `B.Pharm Year 2`). Use proper scrim for text, correct background fit and silhouette detail.
- Wide search pill with actual Search open and appropriate scan/search trailing affordance. Announcements should be an attractive **actual data-driven carousel**, category badge, megaphone illustration, arrow action, page indicators—not merely a single bare text strip.
- `Quick Access`: Study Library / Office Workspace large illustrated cards. Then compact **Shop / Downloads / Study Plan / My Progress** controls with real navigation and real download statuses.
- `Continue Studying` item with real progress/resume behavior and Recent files rows with file type icons and working overflow menus. Preserve activity history and downloaded file status.
- Bottom bar: **Home / Study / Office / Shop / Downloads** from the screenshots. Reconcile with existing app routes/profile/search so destinations still work and do not create duplicate shell navigator keys. Profile may remain accessible by avatar/account menu. Selected state and tap animations subtle; no glow.
- Use custom-drawn/vectors or matching existing icons for illustrated book stack, documents, megaphone, chart. Do **not** crop raster screenshots as component art. Use meaningful loading/empty states in place of invented data.
- Home must work at 320dp, 360dp, landscape/large fonts, keyboard open, and with minimum/maximum app font settings; **no RenderFlex overflow**.

### Six original landscapes and exact time bands

Use **device-local wall clock**, independent of light/dark theme:

| Local time inclusive–exclusive | Phase | Greeting | Runtime WebP |
|---|---|---|---|
| 05:00–08:00 | Early Morning | Good Morning 🌅 | `early_morning.webp` |
| 08:00–11:00 | Late Morning | Good Day ☀️ | `late_morning.webp` |
| 11:00–14:00 | Afternoon | Good Afternoon 🌤️ | `afternoon.webp` |
| 14:00–17:00 | Late Afternoon | Good Afternoon 🌥️ | `late_afternoon.webp` |
| 17:00–20:00 | Evening | Good Evening 🌇 | `evening.webp` |
| 20:00–05:00 (crosses midnight) | Night | Good Night 🌙 | `night.webp` |

- All six original landscapes were **1672×941**. Use optimized originals committed in PR #9, not an AI-generated substitute.
- Keep artwork in the **hero**, not behind entire document list/search or as a full-screen screenshot. Correct alignment, `BoxFit.cover`, gradient scrim; in dark theme preserve black overall canvas.
- Refresh phase on startup, timer boundary, resumed app, timezone/date changes. Use an injected/controlled clock for tests and cancel timers on dispose. Refresh no more often than necessary. Do not reset Home scroll position or the ongoing study timer when phase changes.
- Crossfade ~200–450ms unless reduced-motion is enabled; ideally precache current/next phase only. Graceful asset fallback without crash, but **not** permanent generic image fallback.
- Boundary tests: **04:59→05:00, 07:59→08:00, 10:59→11:00, 13:59→14:00, 16:59→17:00, 19:59→20:00**, as well as midnight and timezone change.
- Compare six actual rendered Flutter heroes with `how it will look.png` and each of six original landscapes; verify light and dark separately.

---

## 5. STUDY TIME — replace superficial counter with real sessions

The timer is the **single source of truth** for Home stats, streaks, charts, goals and campus scoring.

- Start only when the user **explicitly taps Start / Continue Study** or enters a supported actual study activity with clear session policy. Do not award time for the app passively remaining open.
- Add intentional Start / Pause / Resume / Stop, meaningful active/inactive state, visible running indicator, route changes handled. Background or screen locked -> pause; app reopened -> safe resume according to explicit policy.
- Use monotonic elapsed time for actual durations, wall-clock+timezone for local calendar days; **split sessions across midnight** correctly. Prevent overlapping/double-counted sessions and inflated durations after process death or clock change.
- Persist session events in a durable local DB (reuse existing Hive or suitable local stack). Save immediately on pause/stop and periodically while active. Keep it offline first.
- Daily/weekly/custom totals, per-day chart, session totals, streak and goals all derive from **the same events**; no separate arbitrary counters or magic progress values.
- Introduce durable **idempotent sync outbox** for session uploads, queued offline and retried with authenticated identity. Handle partially acknowledged retries, duplicates, server reconciliation and newer offline edits.
- Define anti-cheat rules before any session contributes to competitive Campus Rank. Cloud server validates scoring, never trusts client-submitted rank/points. No private document contents in analytics.
- Tests: start/pause/resume, background, process restart, midnight split, monotonic elapsed, future clock, timezone, connectivity loss/recovery, dedupe and data migration.

---

## 6. STUDY GOALS — match BOTH original Goal PNG references

Use `Goal section screen.png` for the primary full page and the two-pane `goal section screen with reminder and task form.png` for the extended sections and modal designs.

### Screen layout

- Dark navy/black main screen, compact top app bar/back/calendar, `Study Goals` title/subtitle.
- Mountain **This Week's Goal** banner with true achieved vs target hours, blue progress bar and correct percentage.
- Functional **Daily Goal / Weekly Goal / Custom Goal** segmented tabs with independent saved targets.
- Today's Goal card: actual time, planned/finished task counts, progress ring and **Edit Goal** interaction. Don't mix a task-completion percentage with study-duration progress.
- Today's Tasks: saved task list, checkboxes, category, target duration, trailing overflow to edit/delete, working **Add Task**.
- Compact real Campus Rank and Study Streak cards with correct routes.
- Reminders list: toggles, overflow to edit/delete, **Add Reminder**, notification permission/disabled indicators. Toggle must update **actual scheduled OS alarms**.
- Mon–Sun **Weekly Progress** bars reflect real saved per-day study minutes; tap/drill-down to view daily totals.
- Extended: **Insights** (total, daily average, change vs comparable previous period) computed from real history; **Goal Suggestion** computed from recent habits with a functioning Apply action. No hardcoded `+18%`, `60%`, fake graph values or other screenshot placeholders.

### Add Task bottom sheet — reproduce original reference

Required Task Title, Subject / Category dropdown, Estimated Time options **15m / 30m / 1h / 1h30m / 2h / Custom**, Priority **Low / Medium / High**, Due Date, Submit/Save. Add fully functional edit, delete, complete, validation, cancel without accidental writes, keyboard-safe layout, local persistence and optional linked reminder. Subject options should be grounded in the real academic data or editable category list, not fake fixed subjects.

### Add Reminder bottom sheet — reproduce original reference

Required Title, type chips **Study / Task / Goal / General**, date+time, repeat options **Daily / Mon–Fri / Weekly / Custom**, advance alert **At time / 10m before / 30m before**, optional **15-minute snooze / repeat while outstanding**, interval options where relevant, sane quiet hours and stop condition. Implement create/edit/toggle/delete; update local schedules immediately. Validate past dates/invalid recurrence; no unlimited alarm spam.

### Persistence and offline behavior

Goals, tasks and definitions of reminders must work immediately with no network; use local persistence and eventually sync allowed user data when online. Keep migrations safe. Test all form controls, dates, recurrence, changes after restart and syncing on/off, 320dp and large-font bottom sheets.

---

## 7. ANDROID CLOSED-APP NOTIFICATIONS — NOT JUST IN-APP INBOX

This is one of the user's **explicitly missing core features**. Native notification scheduler code exists on PR #9 but was **not device-validated**; do not call it done yet.

- Use a supported Flutter local-notifications plugin with timezone awareness; respect the existing app stack. Check `flutter_local_notifications`, `timezone`, `flutter_timezone`, Android manifest receivers, boot permission, desugaring and plugin compatibility on current Flutter/Android Gradle version.
- On Android 13+, explain and request `POST_NOTIFICATIONS` runtime permission. Handle denied permission via status/settings instructions; do not report “scheduled and will alert” when permission is missing.
- Handle Android 14+ exact-alarm restrictions. Prefer appropriate *inexact* alarms unless genuinely necessary and legally/technically eligible; never falsely promise second-perfect delivery under Doze/battery optimization.
- **Device notification panel must show scheduled reminders even when app is backgrounded or closed**, without internet, subject to permission/OS restrictions. Also preserve in-app notification inbox and unread indicator.
- Reschedule on reboot, app update, time/timezone changes and on launch; cancel on delete/disable/goal completion; reconcile duplicates/idempotent notification IDs.
- Support repeat **daily, weekdays, weekly, custom**; optional repeat/snooze **every 15 minutes** for an outstanding task where user selected it; quiet hours and stop conditions to prevent spam.
- On tapping notification, open correct Flutter route/task/goals page. Support action button `Mark Done` / `Snooze` if available and tested.
- Verify **real physical Android device** or equivalent instrumentation scenarios: app closed, offline, phone reboot, timezone changed, permission denied, DND, low power modes, repeated/remodeled alarm. Web preview cannot prove native Android system notifications work.
- If device testing is not possible, leave feature explicitly **implemented but unverified** and do not represent it as production-ready.

---

## 8. STUDY STREAK SCREEN — actual history + approved 15-minute rule

Follow `streak screen.png`, which shows light illustrated design; adapt dark theme cleanly without glow.

- Mountain hero: actual current N-day streak and “keep it going” status.
- This Week's Streak Mon–Sun checked markers from actual **qualifying days**; do not check future dates.
- Three stats: **Highest Streak / Total Study Days / Current Streak** from event history.
- Recent Breaks: true missed days with dates and previous streak length; See All for full history.
- Streak History: selectable range, actual study-time chart, precise date/duration labels.
- Achievements: **5 / 7 / 14 / 30-day** milestone progress, locked/unlocked correctly. No default fake 5-day streak.
- **Minimum 15 minutes of verified active study per local calendar day qualifies for streak**, per original MD proposal. Earlier PR #8 used 1 minute; ensure all Home and goal pages have been migrated to the unified 15-minute rule.
- Handle interruptions, retrospective offline sync, midnight, DST/timezone change and missed dates without inflating results. Provide empty state/working info button.
- Test current/best streak, breaks, milestones, long-span history and no future dates.

---

## 9. CAMPUS RANK — backend-authoritative, real users only

Follow `campus rank screen.png`, but **all screenshot rank numbers, people, names and points are placeholders** and must **never** be used as production data.

- Header `Campus Rank`, info button, screenshot-faithful campus hero and **verified campus selector** from actual student profile/affiliation. Do not silently treat self-entered institution name as verified.
- **This Week / This Month / This Semester** real period filters. Real current-user rank summary, total verified study time and verified sessions.
- Leaderboard rows: medal/position, privacy-safe avatar/alias, name/year (only if permitted), verified duration, server-authoritative points; pinned You card only if not already present among shown rows.
- Show real `Last updated` timestamp from server, pagination, pull-to-refresh, offline cached view labelled **Last synced**, loading/error/empty states.
- `How Campus Rank Works?` explainer shows actual scoring/verification/eligibility, not marketing text disconnected from backend.
- Implement/review **Firebase Auth + Firestore + server-authoritative aggregation**: verified institution membership, strict security rules, user opt-out/display aliases, pagination, isolation by campus. Do not allow any client to write its own leaderboard score or rank.
- Proposed scoring from original MD (if no previously approved official backend policy exists): **+1 point per verified active minute**, cap **360 scored minutes/day**; **+2 points per valid >=10-min completed session**, cap 5 sessions/day; **+5 points for consecutive qualifying days starting with day 2**, once/day. Rank by score descending, then verified minutes descending, then deterministic UID tie breaker. Define campus timezone and academic semester boundaries.
- Server verifies/authenticates session events, prevents overlaps, duplicate uploads and manipulation; computes stored aggregate/leaderboard. Add Firestore indexes, security rules and Cloud Functions / documented deployment migrations. Do not expose personal docs, emails or reminder texts.
- If Firebase environment permissions/credentials are missing, implement server code/rules/tests and clearly document **not deployed / ranking not live**. Do not show fabricated leaderboard.
- Tests: multiple verified users, ineligible users, opt-out, ranking time periods, ties, caps, duplicates, offline cache, server security rules.

---

## 10. OTHER REQUIREMENTS FROM THE EXISTING MASTER MD — re-audit, do NOT skip

These were approved earlier and remain part of the complete app unless proven implemented and tested. Inspect before editing to avoid regressions.

### Scanner / Office Workspace

- Precise **free-form four corner** page adjustment; correctly detect paper boundaries; native auto-scan and manual capture. Avoid poor page perspective and scan quality.
- Manual shutter latency, crop/rotate, non-destructive preview, saved page fidelity, consistent page ordering.
- Scanner filters preview **immediately without closing picker**; confirm/cancel behavior. `Apply to All Pages` affects all saved pages, not just current preview.
- Unsaved work guard for scan, crop, rotate, reorder, edited pages: **Save / Discard / Cancel** on back/navigation when dirty; no unnecessary warning when clean.
- Review page: **compact Add Images / Save PDF in top-right**, **+ tile after final thumbnail** for additional pages; remove oversized bottom Save/Keep Scanning buttons if the original MD mandates that layout.
- Office Workspace: smaller compact buttons/cards, remove unnecessary “Add name” prompt and unrelated placeholders; retain PDF tools **merge, extract, organize, rotate, edit copy, view**, plus scanner. Working actions only; no fake tools.
- **Share** appears first in each file overflow menu, opens native Android share sheet immediately, maintains original file type, strips exposed UUID/time prefixes from visible shared filename, secure file URI/MIME. No extra Save To Mobile dialogue as intermediate step.
- Reduce/restore bottom nav only during genuine full editor/modal expansion, not while changing ordinary numeric sliders.

### Profile / Settings and app shell

- **Independent font size slider min 6 / max 24**, independent bottom nav size slider, theme selector **Follow App / Light / Dark** for dock; persist and show accurate immediate preview. Enforce readable contrast and accessible touch targets.
- Avatar/profile photo circular crop/zoom with preview, upload and persistence; never replace user's face.
- Bell/unread count functional and discreet glass styling; notification list and deep-links.
- Maintain working five-tab bottom dock and other settings/account routes; avoid duplicate shell crashes. 320dp/large fonts and both light/dark modes.
- Keep PDF viewer, downloads state badges **Downloading / Saved / New**, new/unopened badge clear-on-open and persistence across restart.

### Home data, settings and misc

- No invented announcement content, courses, year, percentages, file names or streak days. Back all visible stats from real provider data.
- Improve actual announcement carousel, hero selection and search/scan action; preserve Shop/Downloads and recent-file workflows.
- Mandatory update/release APK flow, if already in the app: do not remove production signing, existing update prompts, resumable update download or GitHub release workflow during refactor.

---

## 11. Firebase/offline architecture and migrations — must be real

- Existing app uses Firebase Auth/Firestore plus local stores; inspect actual schemas and reuse them where possible.
- Local immediate entities: study **session events**, goals, tasks, reminder definitions, streak cache and **durable pending sync operations**. Persist safe schema versions and migration logic.
- When online, upload idempotent sessions/goals/task completion changes; retry with exponential backoff; handle auth identity, cross-device conflicts, edits made offline and duplicates.
- Server authority for campus membership, verified study durations, leaderboard points and ranking. Keep private reminders/docs local unless optional multi-device sync is explicitly enabled with appropriate access rules.
- Document collection names, security policies, Cloud Function deployment, indexes, rules and rollback. No universal read/write rules or public exposure of private user data.
- Test offline cold start, 100+ pending operations, reconnect, duplicate replay, network flapping, app kill/reinstall where possible, cross-device edits and old-version data migration.

---

## 12. Engineering execution order — do these in sequence

**Phase A — Audit and unblock**

1. Read ZIP + MD + feature branch PR #9, inspect current source/tests, identify exact differences with screenshot. Track each discrepancy in a checked acceptance table.
2. Fix failing Flutter widget tests, 320dp/large-font overflows, Home download badges and hero/profile placement **without weakening legitimate tests**. Re-run analyzer/tests.
3. Confirm optimized six assets included in pubspec and all time bands. Fix theme independence, page refresh and phase transition tests.

**Phase B — Functional screens and data**

4. Rebuild/refine light/dark Home screenshot-faithfully; implement missing carousel, Quick Access, recent, icon art and routes.
5. Complete real Study Time session model, local DB, start/pause/stop, daily/weekly timeline and offline sync foundation.
6. Complete screenshot-accurate Goal page, custom/daily/weekly selectors, task & reminder forms, weekly progress, insights and suggestions; tests.
7. Complete screenshot-accurate Streak page with the approved 15-minute rule, actual history, recent breaks and milestones; tests.
8. Complete Android local notification scheduling, recurrence, snooze, permission/reboot/cancel, deep-links, and test on supported Android versions. Preserve in-app inbox.
9. Implement backend-authoritative campus leaderboard, security rules, scoring, campus verification and pagination. Do not mark deployed until live backend is verified.
10. Re-audit scanner/Office/sharing/settings per §10. Fix uncovered regressions and add tests.

**Phase C — Tests, screenshots, release**

11. Run `dart format`, `flutter pub get`, `flutter analyze`, **full Flutter tests**, Android Kotlin, Android APK build (prefer owner production-signed build when authorized), and `flutter build web --release --base-href "/pharm-d-with-hyzen/"`.
12. Capture actual rendered Flutter screenshots at 320dp/standard/large-text, Home light/dark, all six phases, Goals + both forms, Streak, Rank. Produce side-by-side evidence against the 14 original PNGs, with pass/fail and linked screenshots.
13. Verify actual native offline Android reminders on a test phone/instrumentation and backend security/score before claiming those subfeatures complete.
14. Only after tests/review and essential functionality succeed, mark PR #9 ready, merge into **`main`**, trigger GitHub Pages workflow and verify successful Actions deployment **AND actual live site content** at:
    - `https://horizon003.github.io/pharm-d-with-hyzen/`
    - `https://horizon003.github.io/pharm-d-with-hyzen/#/study-goals`
    - `https://horizon003.github.io/pharm-d-with-hyzen/#/study-streak`
    - `https://horizon003.github.io/pharm-d-with-hyzen/#/campus-rank`
15. If a service or physical testing action is not authorized/available, do **not** bypass safety gates or falsely report full completion. Commit feasible code and tests, explicitly list blocker, credential/permission needed, status, and what is not yet live.

### Build/release safety

- **Never create a replacement signing key** if the current Android release requires the owner's original production keystore. Do not commit keys/tokens/config secrets. If signing is not available, generate only an appropriately labelled test/unsigned build and report production-release blocker.
- Do not fake GitHub Actions success, APK, OS alerts, uploaded Drive file, backend rank or Pages deployment. A web Flutter build success does not mean GitHub Pages deployed; an Android compile does not prove OS notification delivery.
- Avoid force-push/resetting `main`, deleting other contributors' changes, or replacing previous releases without explicit need.
- Prefer small compatible commits and repeatable CI; provide an actual PR with source diffs, tests and screenshots.

---

## 13. Definition of done / acceptance matrix

All rows must be independently verifiable. Mark **PASS / FAIL / BLOCKED**, with a test or screenshot link. No vague “implemented” status.

| Acceptance | PASS requires |
|---|---|
| Original visuals | Side-by-side actual Flutter screenshot comparison of all relevant 7 UI references, six phase images, both form sheets |
| Home light/dark | Proper blue-white light and *true-black* dark; real cards/navigation, no neon/glow, 320dp/large text safe |
| Six backgrounds | Original WebPs decode, exact phase bounds, independent dark mode, startup/resume/timezone transitions, subtle crossfade |
| Study timer | Real explicit sessions, accurate duration, pause/background/restart, midnight, no double counting |
| Goals/tasks | Daily/weekly/custom, validations, edit/delete, accurate charts/insights/suggestion, durable offline data |
| Reminders | Android notification-panel alert with app closed and offline (with permission), recurrent/snooze, reboot, correct tap route, no duplicates |
| Streak | 15-minute qualifying days, current/best, recent breaks, graph and milestone tests, no fake data |
| Campus Rank | Real verified eligible students, secure server scoring, period/rank/ties/pagination/cache, no client point spoofing |
| Scanner & Office | Free corners, clean scanning, filter preview/apply-all, no lost unsaved work, compact action buttons, direct native share |
| Settings/nav | Persistent font/dock settings, accurate live preview, responsive interactive shell |
| Regression suite | Existing tests still pass, including downloads badges, narrow layout, PDF tools, auth and navigation |
| Android | Native build success; release signing validated if production keystore available; notification device test separate |
| Web | Real Flutter build successful, Pages deployed to **exact domain**, fresh build verified via URL and UI |
| Final report | PR/commit/Actions/APK/Pages links, evidence screenshots, detailed PASS/FAIL/BLOCKED list, remaining blockers |

---

## 14. FINAL REQUIRED RESPONSE FROM WORK CHAT

When finished, give me:

1. **Exactly what files changed** and a short description of each major change.
2. **Original screenshot comparison**: matches, deviations, and links/images of actual Flutter renders—not HTML mockup.
3. **Run results**: analyzer, Flutter tests (count and failures), Android build, Web build, GitHub Pages deploy, actual app behavior.
4. **Backend truth**: Firebase rules/functions deployed or not, verified Campus Rank live or not, test evidence.
5. **Native reminder truth**: Android notification-panel tested app-closed/offline/reboot or not; Android OS version and permission state.
6. **GitHub links**: PR #9, merge SHA if merged, Actions, site URL, signed APK/release only if genuinely built.
7. A **feature checklist with PASS / FAIL / BLOCKED** and precise blockers. Never re-label partial code as complete.

### Top-level task to execute now

**Continue PR #9 and systematically close every remaining discrepancy between the user's `Hyzen App Creation(2).zip`, original implementation MD and real Flutter project. Fix current CI test failures first. Then finish genuine screenshot-faithful UI, six provided timed backgrounds, session tracking, Goals/Tasks, 15-minute Streak, Android OS reminders, verified Campus Rank backend, scanner/Office/settings regressions. Run end-to-end verification before merging. Do not deliver another static preview and do not claim success without evidence.**
