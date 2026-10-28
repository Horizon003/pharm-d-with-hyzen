# PHARM D WITH HYZEN — Phase 00 baseline

Audit date: 24 October 2026 (Asia/Karachi). Read-only GitHub audit; no repository, backend, signing, or user-data mutations during this phase.

## Provenance and reproducibility

- Authorized private repository: https://github.com/Horizon003/pharm-d-with-hyzen
- Default branch `main`; inspected HEAD `e19bf01b63df7dffb419e900eb0fa13bc994b304`, commit date 18 October 2026. Branch reports `protected: false`.
- Complete recursive tree returned without truncation. No AGENTS.md in that tree or materialized application source.
- The repository is a build assembly, not a conventional complete Flutter checkout. `.github/workflows/release14.yml` extracts `PharmD_With_Hyzen_Source_1.3.3.zip`, overlays root `lib/` and `android/`, then applies `updates_1_4_0.json` through `updates_1_4_3.json`, in order. Later JSON wins. Editing only a root correction can be silently overridden.
- Source inspected locally comes from GitHub Actions artifact 12148468381, run 39159856906, commit `4899b574fc4132742d1997cecae9dde823c1db94`. Its archive SHA256 was verified against GitHub's digest: `b0145d75a0b54f8c2953d519f0e5944ad887cbcfef2bfd1809fb1c18cc8cf067`. Source package is `PharmD_With_Hyzen_Source_1.4.3.zip` (370 entries). The build formats and applies Dart fixes before packaging, so these are post-format sources.
- GitHub comparison of that commit to audited HEAD shows ONLY release14.yml and verify143.yml changed; no application/patch/base-ZIP changes. Thus the artifact is grounded in the current application's build inputs, not an assumed old snapshot.
- HTTPS git clone lacked command-line credentials; GitHub connector reads succeeded. No local checkout or user's uncommitted changes are available to inspect. Do not represent extracted files as a clean git working tree.
- Handoff: all 44 entries read, all 43 content-manifest hashes verified, 12 phases and 78 traceability cases registered. Handoff functionality remains proposed unless source/runtime evidence establishes it.

## Toolchain and actual dependencies

Application `1.4.3+11`, package `com.hyzen.pharmd`; README at repository root still describes 1.3.3 and is stale. Workflow pins Flutter 3.35.4; Dart requirement ^3.9.2. Java 17, Kotlin 2.3.0, AGP 8.13.2, Gradle 8.13. Minimum Android API 24; compile/target SDK inherit Flutter values and must be read from built manifest before asserting an exact effective SDK.

Locked versions from artifact pubspec.lock: Riverpod 2.6.1, GoRouter 14.8.1, Firebase Core 3.6.0, Auth 5.3.1, Firestore 5.4.3, pdfrx 1.3.5, SharedPreferences 2.5.3, Hive 2.2.3, http 1.5.0. Native: Google document scanner 16.0.0, Latin text recognition 16.0.1, PDFBox Android 2.0.27.0.

Local Flutter, Dart and adb are unavailable on PATH; Java/git exist. No physical Android device or emulator attached through available tools. No local Flutter tests/build or physical scanner performance claims are made. New checks will use an isolated CI workflow, not the release workflow.

## Architecture, navigation, state

Evidence: `lib/app/app.dart`, `router.dart`, `providers.dart`, `lib/features/shell/app_shell.dart`, `lib/core/widgets/main_dock.dart`.

- Material 3, Manrope already bundled, Riverpod providers, GoRouter indexed shell.
- Current visible dock has FIVE destinations: Home, Study (popover), PDF, Shop, Settings. This fails new Q03 four-tab design. Eight retained shell branches are an implementation detail, not eight visible tabs; preserve these routes.
- Auth uses Firebase Auth; guards permit local imported/create/PDF Studio viewer exceptions, preserve register success and legal routes, and redirect non-admin admin routes. Client admin check matches configured Firebase UID; it is not proof of deployed server authorization.
- `professionalYearProvider` reads profile. `content_providers.dart` filters Study/lectures by year for normal users; null year/admin returns all years. Year filtering already exists. Study UI nevertheless retains explicit year/semester drill-down, fixed hierarchy and list rows; requested resource-to-subject flow and recursive mixed-folder thumbnail gallery are incomplete.
- Full route inventory is supplied separately. Existing external document intents are native-controlled; Android Flutter deep-link handling is explicitly disabled to avoid content-URI 404s. Preserve this behavior.

## Backend and privacy

Evidence: `auth_repository.dart`, `content_source.dart`, `content_providers.dart`, `admin_repository.dart`, `shop_controllers.dart`, `firestore.rules.proposed`.

- Firebase/Firestore with `settings/{key}` legacy content, `students/{uid}` profile, `orders_inbox`, `messages_inbox`, `verifications/{token}`. Admin performs transactions on legacy content. No server quiz allocator, question-secret service, transactional attempt policy, or Campus League routes were found.
- Only PROPOSED Firestore rules are provided; file explicitly says deployed rules unknown. No Firebase console/rules deployment access available. Live security is UNVERIFIED, not passed. No real customer/medical/student records were queried during this audit.
- Profile contains full name, mobile, year, institution, roll number, email and photo. Pending/cached profile is stored in app SharedPreferences; other metadata uses Hive without encryption specified in these calls. Threat-model and retention review remain necessary before adding registration PII.
- Proposed verification rules allow public token get; `verificationSnapshot` contains customer names/phone plus city/province, despite the 'masked' comment. This is a privacy review risk conditional on deployed rules, not a proven live breach. Do not copy this DTO into Campus rankings.
- Photo upload uses Cloudinary unsigned preset; provider-side restrictions/rate controls are unverified. No upload performed.
- Firebase public client config is distinct from production signing credentials. Signing is restored only in CI from configured secrets; never replace owner key. No signing secrets retrieved or printed.

## Scanner and file safety

Evidence: `HyzenDocumentScanner.kt`, `HyzenCameraCapture.kt`, `StudioImages.kt`, `StudioPdfEngine.kt`, `scan_page_editor.dart`, `scan_pdf_screen.dart`, `studio_storage_io.dart`, `file_store_io.dart`.

- Main scan is Google ML Kit's external document Activity, JPEG output, 30-page limit. Basic fallback invokes installed camera. No custom in-app live camera/quad detector exists. Main manifest requests Internet/network state/package install, not CAMERA; custom capture will need contextual camera permission.
- Draft pages persist in private `scan_draft`, tracked in `hyzen_scan_draft` SharedPreferences. Recovery logic and instrumentation tests exist.
- `ScanDraftStore.add` decodes to 1800 maximum dimension and compresses JPEG at 88. Rotate/edit recompress, update paths and delete old page images. Crop accepts normalized left/top/right/bottom rectangle, not four arbitrary corners/perspective warp. 'Original' cannot restore an already discarded raw source. New non-destructive transform/draft storage is a high-priority phase 04/05 requirement.
- Offline downloads use app support `offline_docs`, partial/resume journals, validators and document checks; deletion is scoped to managed local files. PDF Studio imports copy into `pdf_studio/workspace`, with separate state files. Preserve identifiers and both file/index layers.
- Existing immersive reader, page tools, native PDF rendering, Latin OCR and copy-based document editing should be retained and regression-tested; not rebuilt from scratch.

## Visual/accessibility inventory

- `tokens.dart` is purple; `palettes.dart` defaults to purple. Changing token alone will not change app default because palette provider supplies seed.
- Five Manrope weights, six premade avatar WebPs, welcome/study/download/search art already exist. Q33 requires at least twelve avatars and coherent new teal artwork; six current assets do not satisfy it.
- Artwork provenance document describes purple generated art. No standalone font OFL/LICENSE file found in extracted source; provenance and license bundle need completion before release.
- Some surfaces/reader transitions honor disableAnimations; dock popover/selection timings do not. No localization delegates or separate analytics SDK found in inspected lib/dependencies; do not claim translated UI or runtime telemetry.

## Validation evidence and limits

- Historical run 39159856906: build job PASS (dependency restore, analyze, tests, web build, native release/instrumentation APK and signature verification). Overall run FAIL because install-smoke failed; deployment job had already succeeded. This is NOT evidence all gates passed.
- Follow-up run 39161094681 at audited HEAD: successful verification workflow for the same signed artifact, including emulator/native/external reader checks. This is historical CI, not a test performed on a physical phone today.
- Existing suite: 14 Dart test files plus two native instrumentation files. Authentication/backend tests mostly use fixtures/mocks. Do not infer live Firestore authorization from widget guard tests.
- Release workflow mutates source with `dart fix --apply` and updates goldens, so it does not prove untouched-input formatting or golden regression equality. It also deploys Pages as soon as build succeeds, before install-smoke finishes. New validation must have no deployment/signing side effects.

## Risk register and restore plan

| Priority | Risk | Action/gate |
|---|---|---|
| High | Source assembly precedence can discard edits | Keep original archive/patches; add explicit phase overlay and teach workflow exact order |
| Critical before backend rollout | Deployed Firestore rules unknown | Obtain current rules; emulator/staging authorization tests before phase 07/08 release |
| High | Draft raw originals discarded / repeated JPEG loss | Versioned raw+transform model and process-death/low-storage tests before scanner switch |
| High | Release auto-deploy precedes device smoke gate | Separate validation-only workflow; no trigger of existing release job |
| High | No physical scanner benchmark | Keep Google/basic fallback until real-device capture/quality tests pass |
| High | Public token verification may disclose PII | Review real rules and response minimization; preserve commerce while designing fix |
| Medium | Default palette and extra tab conflict | Small phase 01 shared-theme/dock patch with route and text-scale tests |
| Medium | Incomplete asset/font provenance and six avatars | Complete license manifest and owner style review in phase 02 |

Proposed review branch: `work/hyzen-phase-01`. Base checkpoint audited SHA above. No main write, force push, migration, app publishing or production deploy. UI-only changes leave Firebase identifiers, Hive box names, SharedPreferences keys, draft directory and scanner channel contracts unchanged. Revert isolated phase commit to restore UI; no data restoration needed. Future storage changes require copied fixtures and migration recovery tests, never uninstall/clear user data. Production restore requires verified owner backup and specific approval.

## Phase gate

Phase 00 repository/source reconnaissance COMPLETE, with environment/live-backend/device limitations recorded. No full-app acceptance claimed. Safe next work: isolated phase 01 theme/navigation foundation and CI validation. Backend changes and scanner replacement remain gated. See PHASE_PLAN.md and TRACEABILITY_MATRIX.csv.
