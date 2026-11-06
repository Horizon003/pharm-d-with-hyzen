# Phase 03 — Study, metadata search and offline hierarchy

State: SOFTWARE CHECKPOINT PASS; native emulator build/test and physical acceptance pending. Isolated review overlay, no release acceptance.

## Observed model and compatibility

Existing settings values use year/semester/subject/section/topic/files. Existing normalizers and IDs remain authoritative. A read-only StudyTree adapter traverses those keys and additive `folders`/`files` arrays under nodes; those extra folders are supported as an extension, not claimed present in production. Published=false parents/files are omitted; existing profile-year/admin scoping remains. Node/depth budgets limit malformed traversal. No backend tree, storage key or academic source is rewritten.

Existing five-level links retain their path. Deeper folders use repeated `folder` query parameters after the five legacy IDs. `?legacy=1` retains the existing LibraryLevelScreen as a rollback view. The normal current-year/sole-semester browser skips redundant navigation, provides compact subject rows, wrapping breadcrumb controls, folder grids and mixed files/folders. Search within a folder is explicitly folder/filename metadata; global search now traverses the same year-scoped tree, retaining enabled-section/product/blog/lecture behavior. No global PDF body-text capability claimed.

## Actual first-page previews

Two-column file cards at normal text scale use actual first-page PNGs rendered through the existing native StudioPdfEngine page-zero renderer. Saved files can render locally; remote previews are user-requested with Load preview, avoiding automatic full-document transfers while browsing. Large text uses one column. The full original reader route remains available if preview fails, format is unsupported, a PDF is encrypted, or the preview exceeds its 16MB network limit.

Preview cache is separate/disposable in private temporary storage, serializes rendering, deduplicates active work, bounds memory (6MB/24 entries) and disk PNGs (12MB), validates cached image decoding, applies a six-hour TTL, uses source version/local modification time and profile UID in cache identity, and verifies exact identity metadata before disk reuse. Download temporary sources/partials are removed; actual saved originals are never deleted. Existing download validation/Drive permission behavior is reused. The PNG renderer is the existing Android native implementation; injected-renderer unit tests do not establish Android/physical-device rendering performance.

## Offline library

Saved/In progress/Failed/All filters reflect existing records, with paused records in progress and invalid ready records retryable. A virtual kind/year/subject hierarchy is built from saved trail metadata, with breadcrumbs and a flat-view switch. Searches span all matching saved records. No file move or key migration occurs; trails remain the source path snapshot at download time. Existing retry, cancellation, partial-transfer journals, delete guards and imported reader history remain preserved.

## Validation plan

New regressions: mixed files/folders, hidden nodes, deep query IDs, legacy normalization, provider year changes, recursive metadata search, virtual hierarchy/status filters, preview cache dedup/restart/version isolation/corruption/size rejection, actual local file/metadata cold restart, missing-file downgrade and recursive UI navigation. Existing full suite and screenshot captures run in review CI. Widget/model result: analyzer clean, all 120 tests PASS and screenshot capture PASS at 2a9fa1892d7d69ec7c3aca618a79f93a6aa32a67 (run 40074996814). Native job still pending. No live backend probe, physical Android/TalkBack/frame-time verification or production build/deployment performed.

## Gate status / rollback

G1–G5 pending automated and visual review. Prior Phase 02 software checkpoint: run 40072570400 PASS, analyzer clean/107 tests; device/live-service gates remain blocked. The documented independent-work variation allows this reversible Study work without claiming those gates passed.

Rollback: remove updates_phase_03.json from review assembly; original route code is retained and `legacy=1` can inspect the previous hierarchy. Cached previews are disposable; existing offline_docs, download record keys, originals and viewer entry routes remain unchanged. Production workflow does not consume any review overlay.

## Native preview verification added

The existing native page-render implementation is factored into PdfPagePreviewRenderer with identical 1800px default behavior; the same channel accepts an optional maxEdge bound. Study requests 320px, reducing thumbnail raster cost before bytes cross into Dart. New Android instrumentation writes a real two-page red/blue PDF, verifies each page's actual PNG pixels/bounds, rejects an invalid index and checks source bytes unchanged. The existing Android suite remains included.

A separate review-only debug build/emulator job runs after Dart checks. It temporarily sets testBuildType=debug in its workspace, preserves the production signing guard and generates a development key only if no development key is present, for the fresh CI emulator. No owner production key is read or replaced; no release workflow or deployment is triggered. Native/emulator results pending. This does not replace physical-device profiling.

The first widget run had clean analysis and passing model/cache tests but three navigation tests stalled because the helper preloaded only the old parser. It now preloads the new parser in runAsync too, retaining real route/back assertions. Settings also has a separate Clear PDF previews action; tests verify this preserves source PDFs and permits regeneration.

## Reviewed software checkpoint

Run 40074996814, source 2a9fa1892d7d69ec7c3aca618a79f93a6aa32a67: clean analysis, 120 tests, screenshot capture PASS. Artifact 12552698409 SHA256 ef1abe4a0cecd74fd4977102661eed4798ce6d881f8adbd2893ec6b9a70292ee matched after download. Light leaf gallery, Downloads and corrected readable icon sheet visually reviewed. A Load preview placeholder is explicitly labelled; it is not presented as a rendered PDF. Native rendering/emulator results remain pending.

A large inline upload truncated one source file in an intermediate overlay. The complete local overlay was republished as a base64 Git blob and verified against its local Git SHA-1 (804eed89fc91a79dd6665a6e668024e22af06978, 194821 bytes). Phase 01 and 02 remote blob hashes also match their complete local files. Current source passes the full suite. Future large overlays must use this verified-blob upload path.

## Native fixture correction

Run 40074996814 compiled the debug app but failed compiling the added test: Android PdfDocument does not implement Closeable, so Kotlin use was invalid. Commit 41b69d583e5978f6f5d232d83fbb319562f9b365 replaces it with explicit try/finally close and scopes Gradle to :app:assembleDebugAndroidTest. Rerun 40083886627 passes analysis/widget/capture; native result pending at this checkpoint. Earlier pending statements refer to their recorded checkpoints, not a native pass.
