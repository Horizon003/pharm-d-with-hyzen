# PHARM D WITH HYZEN 1.5.8 — Adaptive Motion Edition

Fixes narrow Home cards, restores saved text/element sizing with Reset, shows account photos consistently across headers, and replaces the opening portrait with panda onboarding and a real drag-to-continue control. Login and Study Progress use the pastel hierarchy. PDF controls are grey frosted with dark generated icons; Home, scan review and annotation share the smooth selection dock. Home art loops while active with Settings and OS reduced-motion controls.

- [Signed universal APK](https://github.com/Horizon003/pharm-d-with-hyzen/releases/download/v1.5.8-17/PharmD-With-Hyzen-1.5.8.apk)
- [Interactive Flutter preview](https://horizon003.github.io/pharm-d-with-hyzen/) — sample data.
- [Verified publication](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44204487061)
- [Native frame data](https://github.com/Horizon003/pharm-d-with-hyzen/releases/download/v1.5.8-17/frame-timings.json) and [timing summary](https://github.com/Horizon003/pharm-d-with-hyzen/releases/download/v1.5.8-17/profile-summary.md)

Analyzer clean; all 186 Flutter regressions passed. All 15 native scanner/document tests and update-retention/startup checks passed. The original production certificate, com.hyzen.pharmd, versionCode 17 and ARM32/ARM64/x86_64 libraries were verified. The downloaded APK matches SHA256SUMS.txt.

Settings → Display & motion: Text size 90–125%, Element size 90–115%, Reset sizes. Android text scaling remains active; 320/360dp maximum-scale route checks passed.

SHA-256: `c1adfb063236b3d116b9d11c494dd5ab648b7d0c8844be14980d12f901778d6c`

The signed application source is 07665f75e2db648d1c790311ee625f35d231e226. Publication verifies that subsequent profiling/workflow revisions have identical production app files. The initial profiling harness failed; the corrected native profile run 44202616031 completed all five measured scenarios and screenshots before publication.

**60 FPS is not verified.** SwiftShader emulator raster p90 was 362–735ms, beyond the 16.7ms budget. Physical Note 8 GPU smoothness, camera/OCR quality, live Drive and TalkBack still need device verification.
