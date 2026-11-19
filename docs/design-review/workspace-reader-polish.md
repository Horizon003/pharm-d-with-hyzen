# Compact reader and pastel workspace refinement

The owner requested smaller circular controls, floating PDF actions, matching generated academic/document icons, a Home-style Office hierarchy, scanner/editor restyling, a new login panda, and matching account/settings sheets.

## Implementation

- Header glass artwork now occupies a 34dp circle with a 19dp icon in a 48dp touch target. Global icon buttons use a compact visual surface with padded Material tap targets; account Back/Close follows the same geometry.
- Both streamed academic documents and Office files use the shared ReaderScaffold. Its header overlays the document without changing page geometry when hidden. Back is a separate 34dp dark circle; Share/Download/More sit in a dark 34dp-high pill with independent 48dp targets. The file name is black and ellipsized. Page tap hides/shows the header; pan/pinch/text gestures retain their existing listener behavior.
- A bounded native BackdropFilter and 90%-opaque pastel tint replace the solid reader header. The tint supplies contrast even when platform-view content cannot be sampled by blur; Android WebView composition still needs device review.
- One generated transparent 4×4 sheet supplies Notes, Past Papers, Books, MCQs, Scanner, Gallery, PDF, Word, PowerPoint, Edit, Crop, Signature, Settings, Back, Share, and Panda artwork. Flutter clips the original equal cells at render time and shares a cached 1024px decode. The generator source is copied intact into assets/reference/workspace-icons.png; no extra animation dependency is added.
- Study library rows use lavender, blue, mint and apricot surfaces. Drill-down resources receive light category tints. Shared resource/document rows and unavailable Office thumbnails use generated document icons instead of native PDF/Word/PowerPoint symbols.
- Office has a compact scanner hero, Scan/Gallery/Create actions, adaptive Organise/Combine cards, and its existing search/filter/history lists. All import, file operation and navigation callbacks are retained.
- Scanner review uses a lavender canvas, warm header, generated scanner/gallery art, and a dark rounded editing dock. Crop controls retain contrast. Original capture, crop, reorder, filters and save operations are unchanged.
- PDF annotation uses a rounded bottom dock for Select/Ink/Text/Signature plus a menu containing every original tool. Color, stroke, page navigation, edit persistence and export remain available. Reduced motion applies to tool selection.
- The account-choice page uses a new friendly panda, compact buttons, stronger Outfit hierarchy and the shared background gradient. The login form and authentication flow are unchanged. Account/settings surfaces and close/back controls follow the same palette.

## Verification

Final source verification: Flutter 3.35.4 analyzer clean; all 178 tests passed, including the final global button-size adjustment. Six visual/capture cases also passed and refreshed the screenshots. Regression coverage includes reader actions not toggling chrome, fixed document geometry across header visibility, pinch/pan, all annotation tools at 320dp/2× text, a 48dp glass target, scanner crop/capture persistence, navigation, and the six-width responsive matrix.

Actual Flutter widget screenshots are in qa/reference/after/: light_study.png, light_pdf-studio.png, reader-glass.png, account-choice.png, editor-dock-large-text.png, light_settings.png, and other refreshed representative screens. Scanner review/crop captures are in qa/compact-office/. Reader chrome screenshot uses a placeholder document; editor and scanner use a sample-page image and mocked native rendering/camera channels. These are UI verification, not proof of live Drive/network/camera operation on a physical device.

The actual Flutter review entrypoint built successfully for web in release mode. No new signed APK or release is published for this revision. Physical-device camera, live Drive/WebView frost, Android GPU frame timing and screen-reader testing remain pending. No 60 FPS claim is made from widget tests or browser builds.

GitHub authentication in this workspace remains invalid (HTTP 401); local commits are retained, but pushing the branch/updating PR 18 requires the GitHub connection to be authenticated again.
