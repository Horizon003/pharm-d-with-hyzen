# PDF Studio cancellation follow-up

Continues verified checkpoint 71207e76 / app source024bbe86 on work/hyzen-phase-01, draft PR1. Main and release configuration remain unchanged.

## Implementation

PDF Studio now owns a separate cooperative operation session for merge/split/organize, annotation composition, flattening, protection, compression, OCR, text extraction, image ZIP export and PDF/DOCX/text creation. The Dart async zone carries only this session's identifier through sequential native calls. Existing scanner export IDs and finalization remain compatible. Native methods without a Studio job keep their previous behavior.

Control requests run outside the shared heavy-work queue. Cancellation is checked before work, between bounded processing units and around native saving. The dialog stays open until the worker acknowledges its result; it does not fabricate instantaneous cancellation or progress percentages. OCR cancellation waits for the current recognition task to return (the inherited per-page recognition timeout is45 seconds). PDF decoding, encoding and Dart text loading are similarly cooperative boundaries rather than interruptible primitives.

An atomic commit boundary disables cancellation before importing a durable workspace copy or handing a file to Android Save As/Share. Native result generation and this durable-copy phase are separate. Generated files live in a private UUID operation folder and remain there until the destination acknowledges completion. Existing originals, selected pages, writer blocks and persisted annotation layers are retained when processing is cancelled or destination saving fails. Android's own Save As cancellation remains an OS destination outcome after the commit boundary.

Only recognized generated filenames inside the owned operation directory are eligible for cleanup. Unknown files, symlinks, active operations and recent abandoned outputs are retained. Engine detachment marks running work as abandoned and waits for its worker; already produced/saving output receives a24-hour recovery grace period. Only never-started sessions expire after120 seconds; a between-step session cannot lose output merely because extraction or an external handoff takes time.

The dialog supports large text, scrollable content, live status announcements and reduced motion. A delayed Cancel reply cannot update its disposed notifier. Navigation removes the specific processing route; writer/annotation navigation occurs after that dialog closes.

## Changed source

Shared engine and new StudioWorkJobs/StudioExportFormats plus document writer/document operations/maintenance and native tests are owned by updates_camera.json. Operation UI, export/tool/writer/annotation screens, text extraction and Flutter tests are owned by updates_phase_05.json. Final overlay precedence is checked against all16 intended source/test paths; the older camera-owned Dart engine must not overwrite the new async-session wrapper.

## Verification

Source b6d66723b741f879b4c6ad4fb0b3b3540b371882 / run40188260890: canonical326-file assembly (129 total overlay-owned paths), clean analysis11.0s,154 Flutter tests56s, screenshot capture, debug app/test APK builds and all60 Android35/x86_64 instrumentation tests PASS (49.764s). Local source-tool/CSV regressions:13 Python tests PASS. No new native gate remains open for this batch. The initial analyzer correctly rejected an older engine overlay and a missing mounted guard; both were corrected without suppressing lint. The first full suite passed153 tests with only a writer icon-button subtype finder failure; that assertion was corrected while retaining the cancellation/retained-input checks. The earlier145 Dart/49 Android checkpoint does not validate these new native changes. Source-tool regressions were rerun locally:13 tests passed.

Tests exercise client isolation/replay denial, queued and between-step cancellation, atomic cancel-vs-commit races, worker ownership after engine detachment, scoped cleanup, generated-file lifetime through durable copy and failed destination handling. Actual writer and annotation screens verify input/edit-layer retention. Native fixtures cover vector/raster/ZIP/Word/PDF paths and cancellation after OCR page rendering, before recognition begins. Physical OCR cancellation latency and full-device interruptions remain unverified.

## Rollback and open gates

Restore updates_camera.json and updates_phase_05.json together from71207e769c93f78c1c420a213510911d2dbd98f7. Do not delete drafts, saved PDFs, archives or the operation cache as a rollback step; no data migration is required. This is review-branch source work, without merge, signing, deployment, account mutation, question publication or monetary features.

Physical Android quality/performance/accessibility, live Firebase/account/Shop/admin staging, actual trusted quiz backend and approved scoring/time/privacy/duel decisions, rollback rehearsal and production rollout remain separate gates.

Backend-access preparation: the official Firebase integration was discovered as available but not connected. It can provide a supported route to the next backend audit once the owner connects it and identifies a dedicated staging project. No Firebase access, project selection, database write or deployment has occurred. Scoring/duel/privacy policies remain owner decisions.

GitHub evidence metadata: UI artifact12597092490, SHA256 e8cd03b2bd6cb2c71bfa7245222692435bd3df069b9e3fd57b60267dbf5b9c3a; native artifact12596598186, SHA256 894e5ea1718f79644a6802e5db861be4ddba9f21e56f4ccedab062ec5cdc12b5. These are GitHub-reported artifact digests; artifacts were not re-downloaded for this batch. Job logs independently report all11 StudioWorkJobs tests and all60 native tests passing.
