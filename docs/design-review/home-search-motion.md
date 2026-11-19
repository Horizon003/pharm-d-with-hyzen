# Home search, notification inbox and motion refinement

The owner requested an inline search below the calendar, a compact header with search and notifications, generated icons, heavier default text, soft gradients, card hold previews, animated hero art, and removal of in-app font/dock size controls.

## Implemented

- Removed the redundant Downloads/Shop/Search text shortcuts above the dock.
- Added debounced Home search with All/Notes/Books/Lectures/Downloads pills. Books uses the existing guide-books/special library. Downloads searches verified available offline records. Full search retains OCR and advanced file/subject/topic/shop/blog filters in a compact menu; query and scope carry from Home. Nothing is fetched from a new backend.
- Added seven generated transparent pastel icons. Together with the three earlier action icons they now appear in the five-tab dock, header and streak/time/rank cards. Small images decode at display resolution.
- Header buttons use bounded native Flutter glass blur and an outlined circle. The existing unread badge and notification preferences remain functional. The full inbox has gradient surfaces, unread filters and read-all.
- Outfit headings and subtext have stronger weights; body text defaults are 14/13/12dp. In-app size controls are removed, legacy stored values are ignored by layout, and Android text scaling remains enabled.
- Home/Office cards expose a long-press preview with an isolated card, soft modal blur and fade/scale detail entrance. Explicit Open activates the original route. Shared cards have subtle pointer hover/press feedback.
- The search outline/glow changes softly on focus. It has no continuous lighting animation.
- Daily Challenge art uses a finite 2.4-second native transform (5dp drift, maximum ~1.4-degree tilt), then settles. It stops on inactive ticker/lifecycle and becomes static with reduced motion. No animated-image dependency or production GIF decoding is added.
- Streak, time-spent and rank cards have dedicated icons, clear typography and outlined surfaces.

## Verification and artifacts

Analyzer clean; all 175 Flutter tests passed after the final keyboard-submit scope and scroll-padding changes. Coverage includes six widths (320/360/390/430/768/844dp), 2x text, session/data retention, category isolation, offline filtering, Home-to-search query and category transfer (including keyboard submit), notification read-all/unread, removed sliders with OS scaling, modal previews, and hero motion settling/static fallback.

Actual Flutter fixture screenshots: `hyzen_flutter/qa/reference/after/light_home.png`, `light_notifications.png`, `hold-study.png`, `hold-office.png`, plus the other refreshed representative screens. Browser fixture captures under `hyzen_flutter/qa/polish-browser/` include Home search, stats, inbox and a motion video. `rings-trial.gif` is a demonstration recorded from the real Flutter web app, not a production animated asset. Browser recordings use software rendering and do not establish Android 60 FPS. The review entrypoint contains sample data and never changes production records.

No new signed APK is published for this source revision. Physical Android camera, personal profile photo, liquid-glass rendering and GPU frame-time verification remain pending on a device.

Browser limitation: forcing Flutter web accessibility mode before text entry resets the hybrid input field in the installed SDK. Normal canvas and keyboard input was verified and used for the recording; native widget tests cover category and route behavior. The forced web accessibility typing issue remains unresolved in this SDK. Android screen-reader verification remains pending. No production SDK upgrade was attempted.

## Reproduce

From `hyzen_flutter/`, run `flutter analyze` and `flutter test` with Flutter 3.35.4. The full final run completed with 175 passing tests. For visual fixtures, use `flutter test test/navigation_test.dart --dart-define=HYZEN_CAPTURE_QA=true --name "representative screens visual QA|hold previews|notification unread" --update-goldens`.

Build the existing UI review entrypoint (`lib/main_account_review.dart`) for web, serve `hyzen_flutter/build/web` on port 8080, then run `tools/capture_polish_preview.cjs` from the repository root with Playwright and Chromium available. The script records the 390 × 844 review viewport with sample data. `evidence.json` records retained query text and zero uncaught runtime/overflow errors. This does not assert that every network resource loaded or measure native GPU timing.
