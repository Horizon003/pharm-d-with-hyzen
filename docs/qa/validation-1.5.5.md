# Android 1.5.5 validation and native performance

APK: **1.5.5+14**, `com.hyzen.pharmd`, 142,391,464 bytes.
Built source: `5b6e8bfac8d76f88f92d352b4993ca25df6d416e`.
Later commits change CI/evidence only; application Dart, Android and dependency files
are identical across the two profiled revisions and the signed build.

## Functional and release checks

- Flutter 3.35.4 / Dart 3.9.2: analyzer clean; **155 regression/widget tests passed**.
- Responsive matrix: 14 routes, 320/360/390/430/768dp portrait and 844×390dp landscape,
  light/dark, 1×/2× text; no reported layout exceptions. Auth/keyboard and scanner
  regressions have additional focused coverage.
- **15 native Android scanner/document tests passed**; see `native-pdf-tests.txt`.
- Installed the successful 1.5.4 APK, seeded isolated preferences/private file,
  installed 1.5.5 with `adb install -r`, then verified both survived: **passed**.
  These sentinel checks demonstrate installer storage retention; they do not
  constitute a test of a real student's entire account or cloud dataset.
- Real signed APK startup: process alive, no fatal Java exception or signal 11.
- Package/version, minimum API 24, ARM32/ARM64/x86_64 Flutter libraries: verified.
- Production push API constant independently checked in all three AOT binaries.
- Existing certificate SHA-256:
  `3fd902d131ae56d8de4792c9f5953759e2b375e32bcad8f57f7ef5c0ab887f83`.
- APK SHA-256:
  `5bb383d84a8006c3b69fce160ec9813e18518c7ff953b20f450621a1cacff91b`.

[Signed build + update/native/startup checks](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43920554527)
· [signed artifact](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43920554527/artifacts/14255081656)
· [install logs](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43920554527/artifacts/14253784097).

## Native profile measurements

These are Flutter `FrameTiming` measurements in **profile mode**, using the real
Flutter routes and explicitly isolated fixture auth/content. No production student
account or backend writes are involved. Scenarios cover 25 retained-tab changes,
repeated Home flings, route push/pop, and opening a generated one-page native PDF.
Screenshots/readback occur outside measured windows. This is not a large-PDF,
large-library, live-download or physical camera stress benchmark.

Environment: GitHub-hosted Ubuntu runner, Android API 35 x86_64 Pixel 2 emulator,
1080×1920, animations enabled. The runner has no physical Android GPU. Separate
runs use different hosted machines, so the comparison is diagnostic rather than
a controlled same-hardware A/B test. UI and raster timings are separate pipeline
stages; their missed-frame counts must not be added as unique jank counts.

### Default Impeller / Vulkan SwiftShader software emulation

[Run](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43917890697)
· [raw measurements](profile-vulkan-swiftshader.json).

| Scenario | Frames | UI p90 ms | Raster p90 ms | UI misses | Raster misses |
|---|---:|---:|---:|---:|---:|
| Tab navigation | 57 | 7.627 | 319.756 | 2 | 56 |
| Home scrolling | 290 | 4.976 | 342.233 | 1 | 289 |
| Route transitions | 24 | 12.526 | 477.441 | 2 | 23 |
| PDF opening | 10 | 12.174 | 223.861 | 1 | 8 |

### Explicit Skia CPU software rendering

To investigate the emulator bottleneck, reran the same application with
`--no-enable-impeller --enable-software-rendering`. **Production APK renderer
settings were not changed.**

[Run](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43921169790)
· [raw measurements](profile-skia-software.json)
· [native screenshots](https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/43921169790/artifacts/14253728327).

| Scenario | Frames | UI p90 ms | Raster p90 ms | UI misses | Raster misses |
|---|---:|---:|---:|---:|---:|
| Tab navigation | 96 | 1.485 | 22.992 | 0 | 85 |
| Home scrolling | 423 | 1.098 | 42.431 | 1 | 423 |
| Route transitions | 38 | 4.636 | 29.950 | 0 | 36 |
| PDF opening | 12 | 1.358 | 69.260 | 0 | 12 |

## Interpretation and limits

**60 FPS is not verified.** Both emulator configurations miss the approximately
16.7ms raster budget. UI-thread p90 is below budget, but that alone does not mean
smooth 60 FPS. The first run's 224–477ms raster p90 falls to 23–69ms with the
explicit software renderer. This points to substantial emulator/renderer overhead;
it does not establish the production GPU performance or isolate every app paint cost.

The implementation removes landscape decoding/shader masks, recurring background
work, title marquees, idle mascot controllers and pulsing skeletons. It reduces
blur/shadow/clip work, uses small transform/opacity interactions, keeps tab subtrees
stable and uses display-size mascot decoding. No further app-wide renderer switch
was made from a CPU-only emulator result.

Outstanding: repeat native profile runs on representative physical GPU-capable
Android devices (including low-end hardware), inspect raster traces and memory,
and optimize any remaining measured paint/document hotspots. Physical camera,
OCR quality, large-document/list/download stress, battery consumption, full live
sign-in/push delivery and a real student's update dataset remain unverified.
No guaranteed 60 FPS or full physical-device certification is claimed.
