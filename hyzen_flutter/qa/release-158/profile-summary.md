# Emulator profile measurements

Flutter profile mode, API 35 x86_64 emulator using SwiftShader. The 60 Hz frame
budget is approximately 16.7 ms. These measurements include the looping Home
hero; screenshots are captured outside the measured windows.

| Scenario | Frames | UI p90 ms | Raster p90 ms | UI over budget | Raster over budget |
| --- | ---: | ---: | ---: | ---: | ---: |
| tab_navigation | 48 | 17.63 | 444.51 | 6 | 48 |
| home_scroll | 36 | 7.15 | 456.57 | 2 | 36 |
| route_transitions | 30 | 17.93 | 485.66 | 6 | 30 |
| pdf_open | 9 | 18.71 | 361.88 | 2 | 9 |
| ambient_hero | 15 | 35.27 | 734.68 | 2 | 15 |

These are software-emulator measurements and do not establish physical-device
60 FPS. Device GPU, camera/OCR, large live documents and sustained battery/memory
usage still need verification. See frame-timings.json for the raw captured data.
