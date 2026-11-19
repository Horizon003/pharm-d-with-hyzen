# PHARM D WITH HYZEN 1.5.7 — Pastel Workspace Edition

Latest Outfit/pastel UI, compact glass controls, Home search and filters, generated icons, notification inbox, redesigned Office/Scanner/PDF editing controls, and a 22% larger adaptive launcher panda.

- [Download the signed universal APK](https://github.com/Horizon003/pharm-d-with-hyzen/releases/download/v1.5.7-16/PharmD-With-Hyzen-1.5.7.apk)
- [Interactive Flutter preview](https://horizon003.github.io/pharm-d-with-hyzen/) — sample data; native camera/PDF operations require Android.
- [Build, install/update and native profile verification](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44181755143)
- [Native profile captures and raw frame timings](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44181755143/artifacts/14373398066)

Analyzer clean and all 178 Flutter tests passed. Signed build, emulator startup, native document tests and update-retention checks passed. The 1.5.6 installation was updated to 1.5.7 with the original production certificate, preserving the test preferences/private-file sentinels.

Package com.hyzen.pharmd · versionCode 16 · Android API 24+ · ARM32/ARM64/x86_64. The downloaded APK checksum and all three Flutter ABI libraries were independently checked in this workspace.

SHA-256: `bc8b9051a4625ecbc32128fc37261149e5e90381c093465f0113761e48e9aed8`

Original signing certificate SHA-256: `3fd902d131ae56d8de4792c9f5953759e2b375e32bcad8f57f7ef5c0ab887f83`.

Physical-device camera/OCR quality, live Drive/WebView frost, TalkBack and GPU frame-time testing remain pending. The profile capture ran on an API 35 x86_64 emulator using SwiftShader; its log includes a 94-skipped-frame warning. This is not proof of 60 FPS on a physical device. No 60 FPS guarantee is made.
