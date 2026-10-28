# Design references — initial review, 24 October 2026

These are research inputs, not imported component code or licenses for third-party art. Flutter-native implementation and the locked Slate/Deep Teal direction take precedence.

| Requested source | Observed / selected concept | Rejected or held |
|---|---|---|
| https://uiverse.io/ | Community component states; use clear pressed/selected button and chip feedback | No HTML/CSS/React copied; per-author source/license review needed before any reuse |
| https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | README covers Flutter, reflowing essential text, semantic selection and cancellable/reduced motion. Adopt these review criteria | Runtime skill not found in available catalog or scoped local search. No CLI installed/executed; manual guidance review only. Repository states MIT |
| https://opensourceui.in/ | Forms and compact component layout; native form error/focus states | Phone-mockup ornaments unnecessary inside the app. Website advertises MIT; no source imported |
| https://www.toools.design/free-open-source-icon-libraries | Directory for coherent icon families and later provenance checking | Directory includes free and paid resources, not a blanket reuse license. No icon pack imported |
| https://jitter.video/templates/ui-elements/ | Search reveal, toggle, floating menu, progress ring examples; adapt brief native transitions tied to real state | No template export or external runtime. Avoid glow loops and decorative progress implying real work |
| https://www.ripplix.com/ | Public catalog groups success, drag/drop and swipe interactions; useful later for reorder/error feedback | Paid/private material not accessed; no screenshots/art copied; detailed motion comparison still pending |
| https://www.reactbits.dev/ | Text/animation/micro-interaction categories; optional short welcome reveal concept | No animated backgrounds in reader/exam, no React port pasted into Flutter; no source assets imported |

Phase 01 uses an original simple Flutter dock, text wrapping, 48dp control targets and accessible reduced-motion selection. Research is an initial public-page evaluation, not a visual inspection of every animation in those libraries.

Existing Manrope font embeds copyright attribution to The Manrope Project Authors and an OFL URL. The extracted application lacks a standalone OFL text. Preserve attribution and add verified license text in the asset phase. Existing six avatar/illustration assets remain unchanged; their actual generation provenance is documented only by the existing ARTWORK.md and must not be overstated as newly generated.

Next asset gate: original teal style board, owner review before bulk generation, at least 12 avatars, coherent 3D scenes, optical icon review and source/license manifest. No new raster artwork has yet been generated.

## Existing asset size baseline

Six avatars: 61,214 bytes, each 310×320 RGB WebP. Six illustrations: 5,852,978 bytes (five 1254×1254 RGBA PNGs and one 800×1200 RGB WebP). Five Manrope weights: 180,048 bytes. Brand directory: 237,393 bytes. These are source asset bytes, not installed APK size or runtime memory measurements.
