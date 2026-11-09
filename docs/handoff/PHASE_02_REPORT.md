# Phase 02 — Original assets, profile photos and welcome motion

State: PARTIAL. Safe implementation is isolated in draft PR #1. No production release acceptance.

## Approved visual work

Owner approved the casual Gen Z concept on 2026-10-24 ("Okay hain yaay"). Twelve original 320px WebP avatar choices (114498 bytes), five transparent 640px WebP illustrations (254938 bytes) and four original Flutter vector dock glyphs are integrated in the review assembly. AVATAR_ASSET_MANIFEST.json and ILLUSTRATION_MANIFEST.json record provenance, descriptions and hashes; DESIGN_REFERENCE_REPORT.md records the seven references. Generated assets do not carry an asserted exclusive copyright warranty. Legacy saved avatar IDs still render but are not offered as new picker choices.

Home/Study/onboarding use the new artwork; PDF workspace uses empty-folder art. Banner copy and art have separate columns. Decorative entrances are short and nonblocking with immediate reduced-motion alternatives. New glyphs inherit theme colors and existing dock semantics. Full category icon coverage and complete error/download motion remain unfinished.

## Photo crop, preview, save and removal

Edit Profile picks locally, then opens a crop/preview sheet. Zoom and horizontal/vertical controls share the same source rectangle with the 512px PNG export. Cancel dismisses without upload or selection changes. Use photo starts upload through the existing endpoint/preset; successful upload changes the local preview, and the existing Save action persists the profile through PendingProfileStore. Upload failure retains the previous selection. No new service or dependency was installed.

Decoded images are capped at 1600px longest edge; Dart rejects inputs over 20MB, while the existing native picker enforces its stricter 12MB input limit and normalizes orientation/compression. Resources survive the sheet's dismissal animation and are disposed afterwards. Selection/removal/save are guarded during processing; new selection marks the form dirty.

Remove photo/avatar stages an explicit empty-string photoUrl sentinel, renders initials, and persists only on Save. This retains the legacy null-to-Auth fallback without restoring a removed image. Auth photo metadata is cleared after saving non-HTTPS selection/removal; existing asynchronous Auth-update errors remain handled by the inherited flow. Removing a profile image unlinks it; no claim of deleting the remote upload. Live Cloudinary/Firebase persistence/authorization and cross-device synchronization are unverified.

## Welcome session behavior

Home uses real profile/display-name state, with generic greeting when unavailable and no email-shaped display name. A session-scoped playback guard starts after profile readiness, replays neither on rebuild nor route remount, and resets on observed sign-out/account change. Skip and platform reduced motion are supported. The timer is disposed when leaving; Study navigation remains available. No greeting identity is persisted by this new guard.

## Validation

Final source commit: d1840e84d726df71dc40a2d9353471544c0ef574.
CI: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/40071150279
Analyzer clean; 104 tests PASS; representative screenshot capture PASS.

New checks cover portrait/landscape crop bounds and zoom/position extremes, actual exported square-PNG pixels, removal serialization/fallback, crop cancellation, once-per-session claims, profile readiness, skip and remount. Two test-harness issues found in earlier runs were fixed: floating-point comparison tolerance and lazy-list scrolling to Cancel. The existing app regression suite remains included. Screenshot capture is not approved-golden comparison.

Earlier visual review: light Edit Profile, light Study and dark Home; final Gen Z-only gallery/dock captures at 32f7edfd inspected. That artifact (12550776815) SHA256 cd71a4a424b804c39d6db8cacee9de63133b25e54dd37edeb0f4a90e20153091 verified. New crop UI has automated widget/export tests; no physical-device visual or TalkBack acceptance declared.

## Gates and next phase

- G1: Avatar/illustration provenance and seven-site report present; whole asset program incomplete.
- G2: Twelve avatar choices, compatibility and photo controls implemented/tested; live-account verification pending.
- G3: Partial: three related onboarding/study scenes, search/empty art and primary dock symbols; remaining icon/state-motion categories open.
- G4: Named welcome, session guard, skip and reduced motion implemented with automated evidence; physical accessibility review pending.
- G5: Static new raster assets measured at 369436 bytes; APK size delta, low/mid-device frame times, startup/memory and TalkBack NOT RUN.

Phase 03 Study/Offline source readiness is documented in PHASE_03_READINESS.md. No phase-03 implementation or false phase-02 completion claim. Blocking acceptance must be resolved before dependent work advances.

## Preservation and rollback

Review workflow alone applies updates_phase_01.json, then updates_phase_02.json and phase02_assets. Production assembly remains untouched. No merge, deployment, backend migration, production signing or live account mutation was performed during this task. Revert/exclude phase-02 overlay and retain all existing IDs/files/keys for rollback. No user-data migration introduced.

## Remaining visual-state implementation

Three additional original 384px alpha WebP illustrations: error, offline/cache and transfer, 46370 bytes total; STATE_ASSET_MANIFEST.json records provenance/hashes. ErrorState uses error art, cache hint uses static offline art with wrapping truthful text, empty Downloads uses transfer art. Full original icon catalog now 32 glyphs on the same 24-unit stroke grid; shared buttons/badges/resource tiles and category chips use a compatibility adapter, retaining existing labels/actions and Material fallback for unmapped utilities. Campus artwork does not enable features.

Download status uses measured received/total bytes, shows genuine 0% distinctly from unknown totals, never trusts legacy progress without a measured total, and only shows downloaded when the existing ready-record contract is met. Byte interpolation is short; state crossfade is status-only; reduced motion is immediate/static. Pause/retry/delete/download controller logic is unchanged. Icon family capture at 16/24/32px in light/dark and status/reduced-motion tests added. CI 40072570400 at 7c4dedf158fe7eb6f8b60484968c8c6f8e9a21f2: analyzer clean, 107 tests and screenshot capture PASS. Constant IconData lookup was corrected to a runtime map after the analyzer identified that restriction.

Documented execution dependency: after this software checkpoint passes, isolated Study/offline implementation can proceed independently of unavailable physical animation profiling or live profile-sync acceptance. Those acceptance gates remain BLOCKED and prohibit release, without blocking reversible data/UI work that neither changes those services nor activates native scanner defaults. Phase 02 is not labelled fully accepted. The specification explicitly permits completing safe independent work when tools/capabilities are unavailable (START_HERE.md handoff directive).

Software checkpoint: icon sheets at 16/24/32px reviewed in both themes. Artifact 12551702288 SHA256 1b4d070eed3addd98edc67c5f29cc6867253d67bde19373ea0609cc2c7ef156b verified. Device profiling, live backend sync and final release acceptance remain BLOCKED. Independent reversible phase-03 implementation may now proceed under the dependency variation above.
