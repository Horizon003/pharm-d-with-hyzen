# Design references and adaptations

Unslop by **Damir Sokolovsky ([@heydamir](https://x.com/heydamir))**:
https://github.com/heydamir/unslop, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The original skill, references and license are installed in `.agents/skills/unslop`.
Its audit and nine-pass workflow were applied to native Flutter, adapting its
web spacing recommendations to Android's 48dp minimum touch targets and the
owner's supplied mobile references. No endorsement is implied.

Magic UI: https://github.com/magicuidesign/magicui, MIT (copyright Magic UI).
Reviewed `dock.tsx` and `blur-fade.tsx` and their component documentation.
The dock's isolated interaction and the fade's 6px offset informed native
Flutter equivalents (`MainDock`, `HEntrance`, `HyzenPageTransitions`).
These are Flutter implementations, not React components or a runtime dependency.
Blur, magnifying springs, glows and ambient effects were intentionally omitted
under the owner's motion/performance requirements. Full notices are included
alongside this file.

Reviewed revisions:
- unslop: `620163eedb3529d9cd23a3994ed8d287d06f760d`
- magicui: `6f7b531e77659855d4bc1bec8e20fdb0c8199b20`

Poppins: Copyright 2020 The Poppins Project Authors, SIL Open Font License 1.1.
Bundled unmodified font files; full license is in [Poppins-OFL.txt](Poppins-OFL.txt).

The owner explicitly requested the reference gradients, pastel cards, bold geometric
type, photographic onboarding and 3D illustrations in the 1.5.6 revision. These
preferences override Unslop defaults that discourage those particular choices.
The four assets in `hyzen_flutter/assets/reference/` were generated for this app;
the student portrait depicts a fictional person. Existing Hyzen panda artwork is retained.

## Outfit

Outfit is bundled under SIL Open Font License 1.1. See `hyzen_flutter/assets/fonts/Outfit-OFL.txt`. Static weights are instantiated from the Google Fonts variable font; the owner selected this family for the pastel refinement.
