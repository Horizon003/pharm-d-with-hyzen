# HYZEN Time-Based Home Backgrounds

## Implemented

- Wired the six supplied landscape backgrounds into the Home screen atmosphere layer.
- Uses the device's local wall clock and refreshes automatically while the app is open; refreshes again when the app resumes.
- Exact local-time windows:
  - Early Morning: 05:00–08:00
  - Morning: 08:00–12:00
  - Afternoon: 12:00–16:00
  - Evening: 16:00–19:00
  - Night: 19:00–23:00
  - Late Night: 23:00–05:00
- Added light/dark readability gradients while preserving the existing black, white and grey HYZEN visual system.
- Kept the content layer opaque so cards, text and controls remain readable.
- Re-encoded the six supplied PNGs as 1280px-wide WebP assets at quality 82. The six files are approximately 88–154 KB each.
- Expanded boundary tests for all six periods, including 04:59, 05:00, 07:59, 08:00, 11:59, 12:00, 15:59, 16:00, 18:59, 19:00, 22:59 and 23:00.

## Notification review

The existing local study reminder implementation was reviewed without changing unrelated code. The branch already contains Android notification permission handling, scheduled notification and boot receivers, local timezone conversion, stable account/task notification IDs with cancellation before rescheduling, tap-route handling, lifecycle refresh, and account-scoped cancellation on disposal. OneSignal remains separate from local study reminders.

## Verification status

- Static diff review completed; no stale references to the previous phase enum names remain.
- `git diff --check` is required before commit.
- Flutter analyzer, tests and APK build could not run in this sandbox because the Flutter SDK is not installed (`flutter: command not found`). These checks should be run in the project's Flutter CI or a Flutter-enabled development environment.
- No claim is made that real Android background notification delivery was device-tested here.
