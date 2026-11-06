# Phase 05 — scan editing, page review and configurable export

Review branch: work/hyzen-phase-01. Draft PR: https://github.com/Horizon003/pharm-d-with-hyzen/pull/1. Main and the production release workflow are unchanged.

## Implemented

- Read-only Re-detect corners now uses the same conservative detector as the live preview and falls back explicitly to manual corners when ambiguous.
- A saved-file receipt verifies workspace file existence and offers real Open, Share and SAF Save copy to device. Cancellation/errors retain the workspace file.
- The existing immersive reader now has a collapsible quick-action dock and a pill driven by actual native page callbacks; no page count is invented while a PDF is opening or unsupported. Grouped More actions and pointer/pinch behavior are retained across academic, Studio and imported readers.
- Four independent perspective corners, convexity/bounds checks and a 2.5x crop loupe opposite the active corner. Crop preview remains based on geometry before tonal filters.
- Original, Colour, Gray, B & W and Enhance presets; brightness and contrast sliders; before/after comparison and tone reset. Enhance is a deterministic contrast/brightness preset, not AI, OCR or automatic shadow removal.
- Native rendering, preview and high-quality export reconstruct the same reversible graph from immutable imported bytes. Tonal values persist through app restart and saved-scan archive/reopen. Earlier graph records default to neutral tone. Undo/Reset remain available.
- Multi-page selection, select-all and batch removal. Last removed batch and original insertion indices persist in the same preferences commit as the surviving page list. Restore works after recreation. Only one removed batch is retained; a later removal replaces it, and explicit discard clears it. Export archives only surviving pages.
- Explicit discard confirmation protects accidental clearing. Opening a saved archive requires no live pages, pending capture or removal history, preventing accidental mixing of different scans.
- Export sheet: editable filename, standard/high quality (1800/2600 px upper bound), A4/US Letter/US Legal, per-page automatic orientation or forced portrait/landscape, and optional margins. Whole image is fitted without cropping; zero margins does not stretch or guarantee full-bleed coverage of a different aspect ratio.
- PDFBox writes one page image at a time with temporary-file spill. Export validates page identities, conservative free space and final PDF page count. History import and editable archive finish before the active draft is cleared. Export-sheet cancellation starts no operation; failed export preserves the draft.
- Separate private saved archives preserve original image bytes and graph/history. Edit saved scan creates a new editable copy and subsequent save produces a new PDF. Older scans without archived originals report unavailability.

## Verification checkpoints

Prior follow-upaf658df1 / run40136647436 passed analysis/Dart and29 Android instrumentation tests, including removal retention, restart restoration and superseded-batch cleanup. The earlier obsolete deletion assertions are resolved.

Verified source 638b1601051f75212caa645607f66a36eb19a635 / https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40160740655 passed clean analysis, all 129 Dart tests and all 36 Android instrumentation tests. Compile/API and PSS test issues were resolved before this checkpoint. Read-only re-detection, original hashes and five-page capture/export are covered. Phase06 subsequently passed 134 Dart tests at 7e187372; the same run also passed all 36 native tests with the newer Material camera polish. Phase07 checks are tracked separately in IMPLEMENTATION_STATUS.md.

Saved receipt artifact from run40159219984 SHA256 e554717874fc1c4d33fe3f07d966d31ab936ba60a41b02656b0e3131c10b1727 was inspected; its synthetic file metadata/Open/Share/SAF actions remain real operations on fixture files. Landscape crop/receipt captures are also present in the verified Phase06 artifact 12587296628. No golden-comparison result is claimed.

New widgets cover custom camera direct return, explicit legacy fallback, saved receipt/cancelled SAF copy retaining history, actual viewer route and dock/page-pill actions. New native fixtures cover luminance strides/rotation, light/dark quads, stability/Auto rearming, read-only redetection and five captured pages across orientation changes. Screenshot captures are synthetic/emulated review evidence, not physical-device acceptance or golden comparisons.

## Remaining acceptance work

Direct custom camera/overlay and optional Auto are now a Phase04 candidate. Physical-device camera, accessibility, memory/heat and low-storage acceptance remain blocked. The annotation follow-up now implements a collapsible dock, grouped tools, new-mark size/color/opacity, page-scoped Undo/Redo and session-layer restore with acknowledged serialized saves. Its own verification is recorded in ANNOTATION_EDITING_FOLLOWUP.md; cooperative processing cancellation is implemented in the current follow-up; the saved receipt, read-mode dock/pill and crop re-detection are implemented candidates. No physical camera, live backend or release acceptance is implied by synthetic emulator fixtures.

Retained risks: app-owned native workers now share a queue and finalization ownership, with conservative generated-file cleanup; abrupt process death can still leave recent staging files retained for recovery, archived originals use extra storage, and failed archive cleanup can leave a private orphan. Do not delete arbitrary private files as cleanup. A saved archive does not include the removed-pages undo batch.

## Rollback

Editing/archive/export changes are isolated in updates_phase_05.json; updates_camera.json adds receipt, redetection and reader integration. Roll back dependent phase07/06 first, then camera/phase05 in both assembly loops as needed. Removing the overlay is only a code rollback; it does not migrate back saved archives or new tonal state. Preserve user originals and archive manifests during any rollback. No merge, deployment or release signing was performed.

Annotation follow-up b5041bb5/run40168101542 passed clean analysis, all142 Dart tests and capture; unchanged native source2ce85921/run40167440933 passed all37 Android tests. Verified responsive screenshots, move/delete/history/style/failed-save/reopen tests and native opacity/legacy/default/original-integrity evidence are recorded in ANNOTATION_EDITING_FOLLOWUP.md.

Document-hardening follow-up: six app-owned bridges now share disk/decode work, export ownership spans history/archive finalization, and abandoned work/generated files have conservative recovery. Provenance is required before any stale preview reclamation, with immutable originals/legacy/only-copy data retained. Final integrated run40177491328 passed145 Dart/49 native tests; verified provenance/cleanup and ownership artifacts are recorded in NATIVE_DOCUMENT_HARDENING.md. Other PDF-tool cancellation is implemented by the current follow-up; physical/full-host acceptance remains open.

PDF Studio cancellation follow-up: see STUDIO_CANCELLATION_FOLLOWUP.md for session isolation, cooperative checkpoints, atomic destination commitment, actual editor retention tests and the final candidate verification record.

Final cancellation software verification: Source b6d66723b741f879b4c6ad4fb0b3b3540b371882 / run40188260890: canonical326-file assembly (129 total overlay-owned paths), clean analysis11.0s,154 Flutter tests56s, screenshot capture, debug app/test APK builds and all60 Android35/x86_64 instrumentation tests PASS. Local source-tool/CSV regressions:13 Python tests PASS. No new native gate remains open for this batch. Cooperative OCR recognition latency and physical interruption/low-storage acceptance remain device gates.
