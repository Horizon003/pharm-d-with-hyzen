# Phase04 — direct in-app CameraX scanner candidate

Review branch work/hyzen-phase-01; draft PR1. The new final overlay updates_camera.json is applied after phases01–05 by the separate review workflow. Production main/release assembly remains unchanged.

## Delivered source

CameraX1.4.2 camera-camera2/lifecycle/view and AndroidX Activity1.9.3 are pinned for the current Flutter/Android toolchain. New private HyzenScanActivity provides native preview, tap-to-focus, manual shutter, opt-in Auto, torch, zoom, status, page count/thumbnail strip, Review, Gallery and Other scanner. Portrait uses controls below preview; landscape places a scrollable control panel beside preview. Native controls use Manrope, Slate and Teal. Camera permission is requested only when entering Scan. Denial leaves fallback actions available; permanent denial links to app settings. The legacy installed-camera action now checks CAMERA permission before invoking ACTION_IMAGE_CAPTURE.

HyzenLiveScanner bridges the Activity to the existing Flutter scan draft/review. Capture first allocates a private pending output, then commits through ScanDraftStore's immutable original/preview graph. Process-lifetime ScanWork queues disk operations. Five-page capture tests include orientation change, rapid-shutter rejection, recreation recovery, original hashes and readable PDF output. Capture errors leave earlier pages intact. Review during a pending capture waits for completion; app background clears stale detection and turns torch off.

ScanDetector reads only the Y plane with crop/row/pixel-stride and90-degree rotation handling; downsamples to at most256px and analyzes at most every200ms on a dedicated executor with KEEP_ONLY_LATEST. ImageProxy is closed in finally. It uses Otsu foreground/background connected components and a simplified convex hull; rejects frame-touching, low-contrast, tiny, oversized or non-convex regions. ScanStability smooths corners and requires six frames spanning at least1s, acceptable exposure/sharpness/fill, small motion and bounded frame gaps. After capture the page must leave view before Auto rearms. Default capture is Manual; Auto carries a persistent preview notice.

Preview, capture and analysis share a CameraX ViewPort. An automatic crop is applied only to a fresh candidate and only when the saved, EXIF-normalized image aspect agrees with analysis within3.5%; otherwise the original remains available for manual review. This check is conservative, not a substitute for physical corner-mapping acceptance. No proprietary scanner-quality, universal detection or preview-FPS claim is made.

Existing MLKit scanner remains an explicit fallback. Older native builds without the custom channel still route through MLKit/basic camera. Four tabs, existing routes, Study/download data, account services and Shop/admin behavior are preserved.

## Verification

Previous Phase05 follow-upaf658df1 / run40136647436 completed successfully: analysis/Dart suite and Android instrumentation passed, closing the earlier obsolete immediate-delete expectations.

Verified camera/reader checkpoint 638b1601051f75212caa645607f66a36eb19a635 / run https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40160740655: clean analysis in 10.3s, all 129 Dart tests passed in 40s, all 36 Android instrumentation tests passed. The earlier compile/signature/Future API and PSS Long/Int test issues were fixed before this green checkpoint.

Native artifact 12585789804 SHA256 650f8f3cb61f8af3518bc2387c2ae7ad29e18064b5ac5ac6a87eb27ef43b6496 was verified and its portrait/landscape camera screenshots inspected. Five actual emulator rear-camera captures reached the draft; immutable original hashes and five-page PDF export passed. Capture-to-draft samples were 4266, 2658, 2322, 1962 and 2058ms; native Activity-only process PSS samples were 121034, 131211, 118118, 122637 and 115829KiB. These are emulator samples, not peak/leak measurements or physical performance evidence.

Follow-up 9dfc6479 adds a scanner-only platform Material theme, rounded RippleDrawable buttons and tinted controls. Flutter's host theme is unchanged. The screenshot test now waits for actual thumbnail bitmaps. Phase06 run40162938847 at 7e187372 includes this polish and passed all 134 Dart tests plus all 36 native tests. Native artifact 12587183457 SHA256 91ad46834bcbcbf0cabafd7dd2ced565eb9d5603540e11c2b7bb7df566e835fd was verified; both Material portrait/landscape screenshots were inspected with real emulated thumbnails. New capture samples [4093,1982,2814,2378,2070]ms and PSS [116734,123665,127105,128145,129025]KiB remain emulator/native-Activity-only evidence. No physical quality or preview-FPS claim follows.

Native test additions cover padded/strided/cropped/rotated luminance, white/dark skewed quads, blank/background rejection, motion/blur/low-light/frame-gap stability and Auto rearming. Camera smoke uses an explicitly emulated rear camera, captures five pages across portrait/landscape, compares originals and exports five-page PDF. Portrait/landscape screenshots and native Activity-only capture-to-draft/PSS samples are collected. This does not measure the combined Flutter-host memory, physical camera quality, preview FPS, thermals or improvement over the former Google flow.

## Open acceptance gates

No physical Android device identity or consenting-page camera baseline is available here. Low/mid-range phone tests for glare, shadows, patterned surfaces, curved pages, real autofocus/torch/orientation, background/process death, low-storage fault injection, sustained memory/heat and accessibility remain blocked. Auto thresholds are prototype values and must be calibrated against that evidence before release. The phase is not fully accepted.

Cross-channel native ownership still needs hardening beyond the live-session guards. Existing PDF/file operations have separate workers; the new Activity's disk queue does not serialize every legacy service. Process termination can leave unreferenced preview/staging files; cleanup must preserve originals and saved archives. Actual CameraX JPEG resolution depends on device negotiation and is not a promise of the sensor's largest mode.

## Rollback

Remove dependent phase07/06 overlays first, then updates_camera.json from both review assembly loops to restore the previous MLKit/basic-camera flow and earlier reader/export behavior. No new draft schema is introduced; saved originals and graph/history remain valid. Do not delete draft/archive folders during rollback. No production signing, deployment, backend migration or main merge was performed.
