# Native document coordination and safe recovery

Review branch work/hyzen-phase-01, draft PR1. No main merge, production build/signing/deploy or backend write.

## Scope delivered

Six app-owned document bridges now use one process-lifetime disk/decode queue: PDF engine, draft camera operations, fallback scanner postprocessing, external-file staging, MainActivity file operations and CameraX draft/thumbnail work. Activity teardown does not shut down that shared queue. Bounded CameraX luminance analysis, third-party reader/camera internals, updater networking and Dart downloads retain their own execution paths; this is not a claim that all app memory/performance is globally serialized.

Basic-camera preparation moves off the main thread into the shared queue. Pending camera capture and export ownership reject conflicting draft mutations; live/fallback scanner entry checks pending/export state. Existing scanner fallback paths and recovery callbacks remain reachable. Queued draft commands recheck ownership when executed, closing the dispatch-to-worker race.

New scan clients explicitly negotiate retainFinalization. Their export token remains exclusive after PDF generation while Flutter validates the PDF, copies it into history and archives/clears the scan. Only matching-token archive/clear commands are allowed. Cancel returns false after rendering completes; replaying a completed ticket is rejected. The Dart finally block acknowledges completion on successful save, archive failure and cancellation/error. Old Dart clients that do not request finalization retention keep render-only ownership; old native builds ignore the new flag and lack the finish capability without blocking supported legacy export.

Unstarted preparation expires after120 seconds on a monotonic clock. A running export never times out underneath its worker. Engine teardown releases its own unstarted/finalizing ownership or requests cancellation of its own running export, and cannot release another engine's job. Process death resets the in-memory owner; persistent draft/original/archive files are preserved.

New scan exports use dedicated cache/scan_exports/UUID directories. Modern completed/cancelled/failed operations clean their own generated PDF after safe acknowledgment. Abandoned/legacy generated outputs receive a24-hour grace period. Startup maintenance runs on the document queue, protects the active job, skips symlinks/unexpected names and never sweeps general cache or saved workspace directories.

Draft preview reclamation requires all of:24-hour age, no current/graph/Undo/pending reference, a generated-preview provenance record and a still-existing immutable original inside the dedicated scan directory. Legacy/untracked previews, only-copy previews with missing originals, raw originals, camera bytes, archives, unknown files and symlinks are retained. Malformed metadata aborts cleanup. A new preview's provenance is durably recorded before its page graph can be committed. Canonical trusted app roots support Android path aliases without following generated-file symlinks.

## Verification

Final integrated source024bbe86bfd5d3f794dd2b982732c0ccb5eedb6b / https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40177491328 completed successfully: clean analysis11.0s, all145 Dart tests50s, screenshot capture and all49 Android instrumentation tests51.741s. The ten new hardening tests and existing39 native regressions all ran. Native/source builds use the same guarded assembler; all84 review-owned source paths agree locally.

Native artifact12593068902 SHA2567cb82790209afb68506e9565d53c20ebf94a97377f6bb63d43d13670d3ef8a63 was downloaded/verified and reports OK(49 tests). UI artifact12593112486 SHA2567e71210773f8032720689a411aca5092556f7c57f937e98948b72b8fe0a0ecf6 was verified; its editor portrait/landscape PNGs exactly match the visually inspected responsive checkpoint. Fresh native portrait capture with real emulator thumbnails was also inspected. Camera input remains emulated; no physical camera or full-host performance acceptance is inferred.

The migrated dependency cache successfully restored the earlier verified Gradle artifact cache and saved a dependency-keyed cache. No release workflow changed. Source tools67e96c33/run40176797249 separately passed13 Python tests and actual321-file assembly with123 total legacy+review overlay paths.

Ten new native tests cover FIFO/no-overlap queue behavior, unstarted expiry versus running ownership, finalization access/replay/cancel, engine-client teardown, protected references/legacy/unknown/symlink files, trusted-root aliases, real render provenance, missing-original only-copy retention, malformed metadata and active/stale/unknown export cache folders. Updated widget tests verify finalization ticket ordering and draft retention when archive acknowledgment fails, plus finish acknowledgment on cancellation/error. Existing camera/detector/PDF/offline fixtures remain mandatory.

Previous cancellation checkpoint75501203/run40169564707 is now confirmed fully green:144 Dart tests plus39 Android tests. That evidence closes its earlier pending-native status, but does not validate this new coordination/janitor source.

## Rollback and remaining limits

Revert this exact follow-up's queue/journal/ownership/finish-token changes together; retain earlier scanner/editor files and preserve all private data. generatedPreviews is additive metadata; older clients ignore it. Do not delete originals or journals as a rollback step. Production assembly remains unchanged.

Remaining physical gates include real phone camera accuracy/FPS/thermals/full Flutter-host memory and accessibility, interruption/recreation with external camera/MLKit, actual filesystem low-space failures and real viewer compatibility. Live Firebase rules/auth/Shop staging and secure quiz backend/scoring/privacy policies remain unverified. Other PDF operations are not advertised as cancellable; third-party/background engines still need measured device-level profiling. No unrestricted orphan cleanup is enabled.
