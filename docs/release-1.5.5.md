# PHARM D WITH HYZEN 1.5.5 — Nude Motion Edition

Version 1.5.5+14 · Android package `com.hyzen.pharmd`.

- Owner-selected warm nude theme, quiet charcoal controls and compact shared components.
- Content-driven study overview, quiet grey progress and preserved Hyzen panda.
- Five equal navigation destinations with retained stacks and a compact indicator.
- Finite state-driven mascot transitions, press feedback and reduced-motion support.
- Removed six time-switched landscapes, their clock/listeners and automatic scrolling titles.
- Existing Firebase, OneSignal, study sessions/goals/tasks/reminders, professional rankings,
  content fallback, scanner, PDF editing, OCR/search, downloads, shop and admin routes retained.
- Fresh installs use readable text size 13; existing saved choices are retained.

The signed universal APK uses the existing production certificate. Install over
1.5.4 without uninstalling to preserve device data. Release automation verifies
package/version, all three ABIs, certificate and checksum, then runs emulator
startup and profile checks before publishing.

Physical Android device testing, camera/OCR hardware quality and representative
low-end device/battery profiling remain pending. Emulator frame measurements
are evidence for that runner only; they are not a universal 60 FPS guarantee.

Validation: analyzer clean, 155 Flutter tests, 15 native scanner/document tests,
1.5.4→1.5.5 private-data retention check and signed-app startup passed.

**60 FPS remains unverified.** Native profile runs on the CPU-only emulator show
UI-thread p90 1.1–4.6ms with the software-renderer comparison, but raster p90
23–69ms exceeds the approximately 16.7ms budget. Production renderer settings
are unchanged. See the [full evidence and limits](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/docs/qa/validation-1.5.5.md).

Design review uses [Unslop](https://github.com/heydamir/unslop) by Damir Sokolovsky
([@heydamir](https://x.com/heydamir)), CC BY 4.0, adapted to native Flutter and the
owner's nude palette. Interaction references: [Magic UI](https://github.com/magicuidesign/magicui), MIT.

APK build commit: `5b6e8bfac8d76f88f92d352b4993ca25df6d416e` (see provenance.txt).
The release tag also includes later CI/evidence changes; the publisher verifies
that application source, Android files, assets and dependencies are identical.
