# Pastel Planner / Outfit refinement

Owner selected B and then Outfit on 2026-11-17. The production Flutter app now uses bundled Outfit 400/500/600/700 across its theme, Office typography and default announcement text. SIL OFL is bundled with the font. The source is the Google Fonts variable font saved in `font-choice/fonts/`; static instances were created with fontTools.

Home follows the supplied planner reference: centred greeting, stronger apricot/blue/pink plan surfaces, lighter regular-weight card titles and a narrower Office column. The Office panda occupies its own row, keeping it clear of text. Buttons retain compact visual dimensions and accessible tap areas.

The existing five-destination dock is retained, with colour/label/press micro-interactions. Transparent route content now paints onto an opaque canvas before fade/slide, preventing the previous screen from showing through on push/back. Reduced motion remains supported. No backend, route or persisted-data schema changed.

## Validation

- Analyzer: no issues.
- Existing 156-test Flutter suite passed with Outfit, including six widths (320/360/390/430/768/844dp), 1x/2x text and all major routes.
- Eleven representative native Flutter widget screenshots recaptured under `hyzen_flutter/qa/reference/after/`. These are fixture-data screenshots, not physical-device captures.
- Four additional regressions passed: push/pop pixel isolation and rapid narrow-screen tab switching, each with normal/reduced motion. Six existing navigation tests also passed.

This is a source refinement on the existing review branch. No new signed APK or release has been published for these changes; physical-device animation profiling remains pending.
