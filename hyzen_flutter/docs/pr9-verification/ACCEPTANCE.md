# PR 9 verification checklist

Original baseline: d0b76528970b011c60de91df6689b372bcef1dc2.
All 14 original ZIP PNGs inventoried and visually inspected. Previous scratch
session was reset before its changes were committed. Only new runs on this
checkout count as final verification.

| Area | Work required | Status |
|---|---|---|
| CI | Duplicate hero key caused 2 test failures | Fix committed locally; verification pending |
| Home | Original light/dark composition, compact cards, real carousel and year control | In progress |
| Landscapes | Original six images; boundary/resume refresh and greeting | In progress |
| Timer | Monotonic sessions, midnight split, safe durable persistence, outbox | In progress |
| Goals/forms | Edit/delete, custom duration/recurrence, accurate goals/insights | In progress |
| Streak | 15-minute rule, future dates, full breaks and achievements | In progress |
| Rank | Server scoring, verified membership, rules, pagination/cache | In progress; deployment not verified |
| Android reminders | Recurrence, bounded snooze, quiet hours, device evidence | In progress; device test not performed |
| Office/scanner | Non-destructive filters, unsaved guard, compact actions | In progress |
| Profile/settings | Circular crop, font/dock sliders and theme | In progress |
| Visual QA | Real Flutter 320/360/standard/large-text renders, both forms and six phases | Pending |
| Builds | Full tests, analyzer, Kotlin, APK, release Web | Pending |
| Merge/Pages | Gate remains closed until essential features verified | Not merged/deployed |
