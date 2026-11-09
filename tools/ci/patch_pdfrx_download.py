#!/usr/bin/env python3
"""Patch the cached pdfrx CMake downloader for resilient CI-native builds."""
from __future__ import annotations

import os
from pathlib import Path


def main() -> None:
    pub_cache = Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache"))
    roots = sorted((pub_cache / "hosted" / "pub.dev").glob("pdfrx-*/android/CMakeLists.txt"))
    if not roots:
        raise SystemExit("pdfrx CMakeLists.txt was not found after flutter pub get")

    old = (
        "    file(DOWNLOAD https://github.com/bblanchon/pdfium-binaries/releases/download/"
        "${PDFIUM_RELEASE}/${PDFIUM_ARCHIVE_NAME}.tgz ${PDFIUM_RELEASE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz)"
    )
    new = """    # Prefer the repository mirror so APK builds do not depend on GitHub's
    # release-assets endpoint. Keep curl as a resilient fallback for local use.
    if(DEFINED ENV{PDFIUM_MIRROR_DIR} AND EXISTS "$ENV{PDFIUM_MIRROR_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz")
        file(COPY "$ENV{PDFIUM_MIRROR_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz"
             DESTINATION ${PDFIUM_RELEASE_DIR})
        set(DOWNLOAD_STATUS 0)
    else()
        execute_process(
            COMMAND curl --fail --location --retry 6 --retry-all-errors
                    --connect-timeout 30 --max-time 600
                    https://github.com/bblanchon/pdfium-binaries/releases/download/${PDFIUM_RELEASE}/${PDFIUM_ARCHIVE_NAME}.tgz
                    --output ${PDFIUM_RELEASE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz
            RESULT_VARIABLE DOWNLOAD_STATUS
        )
    endif()
    if(DOWNLOAD_STATUS)
        message(FATAL_ERROR "Could not download PDFium binary for ${ANDROID_ABI}: ${DOWNLOAD_STATUS}")
    endif()"""

    patched = 0
    for path in roots:
        text = path.read_text()
        if old in text:
            path.write_text(text.replace(old, new))
            patched += 1
        elif "--retry-all-errors" in text:
            patched += 1

    if patched == 0:
        raise SystemExit("pdfrx CMake downloader shape was not recognized")
    print(f"Patched {patched} pdfrx CMake downloader(s)")


if __name__ == "__main__":
    main()
