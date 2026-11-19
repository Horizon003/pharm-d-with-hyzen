# Actual-font comparison — Outfit selected

The user selected Pastel Planner (B), asked to retain the latest native navigation and requested modern font samples before choosing. This board compares **Outfit**, **Sora** and **Plus Jakarta Sans** using real font binaries in Chromium. It is a reference-inspired typography concept with sample data, not a Flutter screenshot or a release preview. Outfit is the recommended visual match; no claim is made that it is the exact source-image font or a statistically verified trending font.

All panels use identical sizes, colours, layout and weights: feature heading 28/600, section 20/500, card titles 18/400, body 12/400, compact buttons 11/500. The small illustrative assets come from the existing application. Card controls in this comparison are visual specimens, not validated production touch targets. Native implementation must preserve 48dp touch targets, font scaling and constraints.

- `font-comparison.png`: complete board, rendered at device pixel ratio 2.
- `preview.html`: inspectable typography specimen.
- `capture.cjs`: repeat with `node docs/design-review/font-choice/capture.cjs` from the repository root. Uses Playwright and `/usr/bin/chromium`; starts a temporary loopback server and closes it after capture.
- `fonts/`: unmodified Google Fonts variable TTFs and their SIL Open Font License files. Sources: `https://github.com/google/fonts/tree/main/ofl/outfit`, `.../sora`, `.../plusjakartasans`, downloaded 2026-11-17.

The capture confirms all three font faces loaded. No production theme, Flutter font bundle or app behaviour is modified by this preview.

User selected **1 — Outfit** on 2026-11-17. Native app now bundles static 400/500/600/700 instances from the original variable font, with its OFL. Other families remain comparison-only.
