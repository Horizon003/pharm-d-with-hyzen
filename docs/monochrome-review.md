# Nude Motion review

Baseline: `a2efde557c4c0536cf95932488e68f505c6834d9` (latest successful 1.5.4+13).
Native Flutter project: `hyzen_flutter/`. No historical source overlays applied.

## Final palette (owner revision)

The owner supplied mobile layout references and explicitly replaced the original
strict monochrome request with **nude tones**. The final implementation uses warm
cream `#FBF7F2`, paper `#FFFCF8`, sand `#F0E7DC`, muted peach `#E8CDBB` and charcoal
`#43372F`, with warm dark equivalents. No saturated purple/blue theme or glowing
background is reintroduced. Earlier monochrome commits are intermediate history;
the `after/` captures show the final owner-directed palette.

## Unslop direction

- Product: academic resources and document productivity for Pharm D students.
- Character: exact, calm, studious.
- World: paper, ink and the study notebook.
- Moments: real study progress and the existing Hyzen panda.
- Signature: a narrow progress line and the panda's finite response to app state.

The owner's detailed brief explicitly authorizes this direction and implementation.
Skill installed in `.agents/skills/unslop`; see [attributions](third-party/README.md).
The native application cannot run Unslop's Playwright HTML snapshot script.
Its documented audit/pass/check workflow is applied directly to Dart and actual
Flutter raster captures, without an HTML recreation.

## Audit and passes

| Area | Baseline finding | Implementation |
|---|---|---|
| Spacing | Tall landscape section, dense captions, large nested radii | Content-driven Home summary, 4dp rhythm, 12–16dp panels |
| Color | Blue theme overrides, coloured categories and progress | Explicit warm neutral ColorScheme and presentation constants; semantic status colours retained |
| Icons | Coloured badges and large dock icons | Neutral role colours, 20dp dock icons and equal targets |
| Copy | Uppercase greeting, long search prompt | Sentence-case greeting, shorter search label |
| Type | Heavy 800/900 weights and fresh-install size 8 | 400/500/600 hierarchy; fresh-install default 13; saved preferences retained |
| Layout | Time-switching hero and positioned actions | Intrinsic summary/actions and adaptive statistic wrap |
| Detail | White glow rims and repeated heavy shadows | Hairlines and small neutral lift; dark surface steps |
| Visual | Six decorative landscapes on Home/Goals/Streak/Rank | All six assets and their clock rendering code removed; panda retained |
| Motion | Continuous title marquee, pulsing skeletons, idle mascot controllers | Static titles/skeletons; finite mascot state transition, press feedback, small route fade/slide |

## Feature preservation

Data/services and production Firebase/backend identifiers remain unchanged.
All current router paths and shell branch indices are retained. Existing regression
coverage checks session persistence, daily/weekly/custom goals, reminders, streaks,
ranking sync, academic fallback, OneSignal routes, CSV admin tools, download lifecycle,
PDF scan/compose/merge/extract, OCR indexing and profile/account preferences.
Legacy admin palette metadata remains stored; the displayed product palette follows the final nude direction. Document annotation ink remains semantic user content.

Removed: time-dependent decorative landscape artwork, its timer/lifecycle observer,
endless title scrolling, pulsing skeleton decoration and mascot idle controllers.
No academic, commerce or document feature is intentionally removed.

## Evidence

`hyzen_flutter/qa/monochrome/before/` contains baseline Flutter captures.
`after/` contains redesigned captures in both themes. These are actual Flutter
widget rasterizations with fixture data, not web mockups or production account data.
`matrix/` is generated on demand for responsive review; it is not a frame benchmark.

Native profile integration exercises retained tabs, Home scrolling, route pushes,
and a generated on-device PDF separately. Readback/screenshots run outside measured
windows. CI uploads raw `FrameTiming` summaries under `monochrome-native-profile`.
Actual results and any limitations are recorded after validation; no performance
claim is inferred from widget-test speed.

## Local validation

- Flutter 3.35.4 / Dart 3.9.2, matching production CI.
- `flutter analyze --no-pub`: no issues.
- Full regression suite: 155 tests passed, including the three new motion tests.
- Monochrome/reduced-motion tests: 3 passed.
- Expanded responsive matrix: 14 screens × 6 sizes × 2 text scales × 2 themes;
  includes 320/360/390/430/768dp portrait and 844×390dp landscape, with no
  reported Flutter exceptions or RenderFlex overflow.
- Actual Flutter captures: Home, Study, Office, Downloads, Profile, Settings,
  Goals and Admin in both themes. Fixture data is explicitly separate from production.
- Android signature/version/ABI/update/startup checks and 15 native tests passed;
  see [actual native performance and validation](qa/validation-1.5.5.md).

Open limits: no physical device or camera hardware in the coding environment.
Widget rasterizations do not establish GPU frame rate. Native timings are recorded in the linked report; the hosted emulator does not
meet the 16.7ms raster budget. Physical GPU verification remains pending.

## Owner-provided mobile references

The additional references inform the native layout: an actual study-week ribbon
with today's neutral pill, compact content cards, and a centered focus ring with
the Hyzen panda. The ring represents real progress toward the saved daily goal;
it is not a fabricated Pomodoro countdown. Existing active-session start/pause/stop
and persistence remain on the real tracker. No reference photos, 3D assets, logos,
purple/blue palette or promotional claims were copied.

## Capture index

| Screen | Before (light / dark) | Final nude (light / dark) |
|---|---|---|
| Home | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_home.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_home.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_home.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_home.png) |
| Study | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_study.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_study.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_study.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_study.png) |
| Office | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_pdf-studio.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_pdf-studio.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_pdf-studio.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_pdf-studio.png) |
| Downloads | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_downloads.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_downloads.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_downloads.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_downloads.png) |
| Profile | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_profile.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_profile.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_profile.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_profile.png) |
| Settings | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_settings.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_settings.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_settings.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_settings.png) |
| Goals | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_study-goals.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_study-goals.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_study-goals.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_study-goals.png) |
| Admin | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/light_admin.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/before/dark_admin.png) | [light](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_admin.png) / [dark](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/dark_admin.png) |

[Final focus timer](https://github.com/Horizon003/pharm-d-with-hyzen/blob/work/monochrome-motion-1.5.5/hyzen_flutter/qa/monochrome/after/light_study-progress.png).
