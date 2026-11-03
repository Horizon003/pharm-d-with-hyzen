# PHARM D WITH HYZEN

Flutter Android app, com.hyzen.pharmd, source version **1.5.3+12**.
Read docs/COMPACT_READER_1_4_2.md first for new changes and validation status.

Pending module work includes the student-facing admin preview, confirmed content publishing, nested Study File Explorer with real PDF previews, searchable Settings accessibility controls, and first-run tutorial persistence/replay. The PR validation workflow runs `flutter analyze` and `flutter test`; it does not build an APK.
Use Flutter 3.35.4 / Dart 3.9.2 and JDK 17.

PDF Studio includes Create PDF / native document scanning, on-device Latin OCR,
lossless page operations, editable PDF annotations, AES password and compression
exports, and a structured PDF/DOCX writer. Read docs/PDF_STUDIO_1_4_1.md for
scope and physical-device requirements. Drive cloud setup remains pending;
original online preview and public offline downloads now work as fallback routes.

This update restores the owner's five-item floating reference dock with a nested
Study menu, a compact PDF workspace and durable camera/gallery page drafts. It
also improves compact layouts, removes duplicate downloads artwork, simplifies
login errors, fixes mobile-number error recovery and confirms profile saves.
Profile includes a swipeable promotion carousel driven by the existing catalog.
PDF reader supports text search, previous/next match, page controls and zoom.
The Studio top bar has Edit, bookmark and overflow tools.

Read **docs/DRIVE_PIPELINE_1_4.md** before testing live Drive files. The native
Drive API/PDFium pipeline needs owner Google Cloud API/OAuth setup. The existing
Firebase key is restricted from DriveFiles.Get and no Android OAuth client is
configured in the original Google services file. Missing/disabled API setup
automatically selects the original Google online preview. Public downloads use
Google's download/export endpoints, including bounded large-file confirmation;
Google still enforces file permissions and download restrictions. Native API
reading remains the preferred configured route, with an Online preview action
if the reader fails. This app contains no service
account credentials or OAuth client secrets. The Google connection is optional
for local files and separate from email/password app login.

Native offline transfers stream to app storage, show progress, retain paused
partials and resume when validators and HTTP Range permit. A PDF is finalized
only after type/end-marker/length checks. Deletion only affects local copies.

The project retains all existing backend URLs and existing owner signing
identity. Release signing secrets are excluded from this archive and restored
only in the owner's private GitHub build. Do not replace the key.

Build:
    flutter pub get
    dart format lib test
    dart fix --apply
    flutter analyze --no-pub
    flutter test --no-pub
    flutter build apk --release

Actual live Google speed comparison, signed-in backend acceptance and physical
phone gesture testing require the owner's configured accounts/devices.
PDF Studio page manipulation preserves text/vectors; flattening is explicit.
See docs/PDF_STUDIO_1_4_1.md for implemented tools and remaining format limits.
