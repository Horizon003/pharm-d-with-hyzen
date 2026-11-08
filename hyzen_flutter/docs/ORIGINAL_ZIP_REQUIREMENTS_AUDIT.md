# Hyzen Original ZIP vs Flutter Implementation — acceptance audit

Source: **Hyzen App Creation(2).zip**, 14 supplied PNG references; original `Hyzen_Design_Implementation_Prompt.md`.
Status: **in progress, not release-ready**. Do not merge PR #9 or describe live Pages as updated until all required checks pass.

| Requirement | Status | Verification still needed |
|---|---|---|
| Preserve original six landscapes | Implemented on feature branch | All six 1672×941 WebPs bundled in `assets/home_backgrounds/`; decode/UI screenshots on devices |
| Six exact local-time windows | Implemented on feature branch | Time boundary test and app background/resume/time-zone simulation |
| Independent dark/light theme | Implemented visually in Home section | Compare actual screenshots in both themes, avoid glow and scrolling jank |
| Homepage reference study-time, streak/rank/week, hero | Reconstructed on feature branch | Screenshots at 320/360dp and large text; 1:1 reference review still open |
| Exact Goals page, custom goal, task/reminder sheets | Partially implemented | Form controls, recurrence, edit, charts, insights, suggestion and original sizing require acceptance |
| Streak real history / 15-minute qualification | Partially implemented | History, data integrity, timezone and achievements require integration tests |
| Campus Rank real verified campus leaderboard | UI + Firestore read path added | **Cloud validation, Firestore security rules, server-side scoring, eligibility, anti-spoofing, pagination and deployed backend missing/unknown** |
| Android closed-app reminders | Native scheduling code added on branch | **OS permission, device reboot, app killed, quiet hours, 15-minute repeat/snooze, battery policies and tap handling require Android device tests** |
| Real study sessions and offline-cloud sync | **Not complete** | Idempotent session outbox, per-day midnight split, server reconciliation, secure ranking aggregation |
| Scanner / Office / sharing / settings improvements | **Not audited/completed in this PR** | Existing feature acceptance against section 11 of MD |
| CI analyzer | Passed in most recent run | Re-run after changes |
| Flutter widget tests | **Failing in most recent run** | Restore downloads badges, small-screen accessibility/layout, reference hero tests |
| Android native build + Web preview | Previously compiled; next run pending | Build after current test fixes and verify Pages deployment |

## Release gate
- `flutter analyze --no-pub`, all existing and new widget tests pass.
- Android scanner build + full Android app build, Web build, live GitHub Pages deployment verified.
- Compare real rendered Flutter screenshots with every supplied UI reference, not HTML/static mockups.
- Validate OS reminders on a physical Android 13+/14+ device.
- Never invent Campus Rank positions, other students, leaderboard scores, sync success or data.

All unverified features stay flagged as incomplete even if a partial UI exists.
