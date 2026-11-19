# Archived 1.5.5 Flutter UI preview

[Open the live preview](https://hyzen-nude-ui-preview.deepparsnip16.chatgpt.site). The host is owner-private; use the same ChatGPT account that requested it.

This deployed Site contains the older 1.5.5 design. The owner paused further preview work; current 1.5.6 captures are linked from [the reference review](reference-redesign-1.5.6.md).

The older live preview runs `hyzen_flutter/lib/main_account_review.dart`, using the
actual application widgets, router, design system and local study tools. The
surrounding HTML provides screen, theme, viewport and accessibility text-size
controls; it does not reproduce the app UI.

The entrypoint uses isolated sample auth/content/download/Office/admin adapters.
It initializes no Firebase application and performs no production admin writes.
Registration, sign-in and administrative saves report that they are preview-only.
Camera, native scanning, OCR, PDF editing and offline file operations require the
Android APK. Sample file paths are illustrative and are not downloadable PDFs.
Shop and orders retain the app's coming-soon/empty presentation.

Build with Flutter 3.35.4:

```sh
HYZEN_FLUTTER_BIN=/absolute/path/to/flutter tools/live_preview/build.sh
```

Serve `hyzen_flutter/build/live-preview` at the host root. The app is at `/app/`;
its base href is `/app/`. CanvasKit resources are bundled locally. The launcher
links directly to the same app for full-screen use. URL example:
`/app/?theme=dark&textScale=1.3#/study-goals`.

Deployment uses an owner-private Sites host. GitHub Pages retains its existing
deployment branch policy: this integration cannot add the development branch
(HTTP 403). No branch protection was disabled. This separate preview does not
replace the production GitHub Pages application or the signed Android release.

Validation: Flutter analyzer, release web compilation, existing navigation and
monochrome/motion widget regression tests, launcher JavaScript syntax and static
asset/path checks. Managed browser tools (`cua_repl.js`) and the Sites source
helper are absent in this environment; publication uses ordinary Git with the
returned repository credential and an archive of the exact pushed static build.
A browser visual pass of this hosted preview remains unverified here.
