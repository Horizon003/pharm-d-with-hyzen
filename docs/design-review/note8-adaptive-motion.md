# Note 8 layout and interaction refinement

Home's narrow two-column plan could break long words on smaller Android layouts. The plan now stacks at narrow widths or large text settings, with natural labels and content-driven card heights. Regression checks cover 320/360dp and app/system scaling combinations.

Settings now has saved Text size (90–125%) and Element size (90–115%) sliders, visible percentages and Reset sizes. Text combines the selected factor with Android's text scaler. Element size adjusts shared card padding, generated icon dimensions, dock height and Material density. A separate ambient-animation toggle is saved. Maximum tests use Android 200%, app text 125% and elements 115%, with scrolling across Settings, Study, Office, Downloads, Study Progress, Notifications and Search.

Headers consistently resolve the saved student photo before the auth-account photo. Onboarding opens with a generated panda. Continue has a real horizontal drag threshold, short/cancelled-drag snapback, once-only completion and an accessible tap action. Login has a centered panda, pastel header, rounded floating form and unchanged sign-in/reset/autofill behavior.

The Home shapes now repeat a restrained native transform while active. Motion stops when hidden, paused, disabled in Settings or reduced by the OS. Study Progress uses pastel panels and generated timer/goal/streak icons; tracked sessions, goals, tasks, persistence and ranking logic remain active.

Home, PDF annotation and Scan Review share a soft dock with fixed touch slots, white inactive controls and a moving selection pill. This avoids repeatedly resizing neighboring controls during selection. Actual callbacks and disabled states are retained. The PDF reader uses a frosted grey header, dark generated Back/Share/Download/More controls and a black file title. Page taps still hide/show the chrome without changing document geometry. Generated Rotate/Delete controls are used across review, page organisation and editing actions.

The unread badge sits outside the clipped glass surface, within its 48dp target. Compact count rendering and the full semantic unread number are verified at 2.5× text scaling.

## Evidence

Implementation by requested GPT-6.2 Sol: commits 2bb5b97 and 07665f7. Analyzer clean. The full pre-badge suite passed 184 cases; the added maximum-size route regression and badge regressions passed separately. The release CI runs the complete final suite again.

- Native Flutter widget captures: hyzen_flutter/qa/reference/after/home-note8-large.png, light_login_form.png, light_welcome.png, light_study-progress.png, reader-glass.png and editor-dock-large-text.png.
- Scan/crop captures: hyzen_flutter/qa/compact-office/.
- Signed build, native profile and update validation: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44196563697
- Pages deployment: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44196569274

The screenshots and responsive checks are fixtures, not physical Infinix captures. Actual Note 8 camera/Drive behavior, OEM text rendering and GPU frame times still require device verification. No guaranteed 60 FPS claim is made from emulator measurements.

## Completed release

Signed 1.5.8+17 published: https://github.com/Horizon003/pharm-d-with-hyzen/releases/tag/v1.5.8-17 . Publication run 44204487061 validated the signed source against the corrected native profile source, original certificate, checksum, version, ABIs, retained data and all 15 native document tests. Detailed measured frame timings and limitations are in docs/release/1.5.8-validation.md. The raw data are attached to the release. The original profile harness failed and was replaced by a verified rerun; its failure was not ignored.

The complete final suite passed all 186 cases in the signed-build job.
