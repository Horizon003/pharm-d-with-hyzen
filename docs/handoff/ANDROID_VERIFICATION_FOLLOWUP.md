# Android verification follow-up

Branch work/hyzen-phase-01, PR 1. Follow-up source 4aa3d0e2db36ced8185cbb345736ba7b9cd1b703.

## Observed failure

Phase 03 run 40083886627 built the debug app and instrumentation APK successfully. The emulator never booted: the runner had only 90 MB left, and installing android-35 default x86_64 failed with No space left on device. This is infrastructure failure, not a passing or failing app instrumentation result.

## Fix

The review-only native job frees unused .NET/GHC/Boost/CodeQL directories on its disposable runner before building. It checks for at least 8 GiB before emulator setup, records filesystem usage, and builds the review APK for android-x64. The production workflow and application dependencies are unchanged. Run 40084836592 rechecks the same scanner source and tests. Result pending.

## Scope still blocked

No physical Android phone or camera benchmark is available. Direct camera, temporal corner detection, torch/orientation capture and perspective-quality acceptance are not delivered. Do not mark Phase 04 complete from emulator store tests. Native regression gate must pass before dependent scanner activation or release.

Rollback the workflow-only follow-up by restoring phase01-check.yml from ca698555e9d24796f698e84ce15b397129454877. Do not remove the successful PdfDocument fixture resource-close correction.
