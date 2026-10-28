# Phase 03 — Readiness review only

No phase-03 implementation yet. Source inspected on the phase-02 review branch.

- Current Study uses `lib/features/academics/presentation/library_screens.dart`, fixed year/semester/subject/section/topic resolution and ResourceTile rows. Keep current deep links/section permissions while introducing compact subjects, mixed folders and breadcrumbs.
- Profile-year filtering is already in content providers; preserve source keys and test year changes against both cache and refreshed data.
- First-page thumbnails must use the installed pdfrx rendering capability and actual PDFs; do not substitute generated document art.
- Downloads controller, download records and file_store_io implement existing persistence and retry behavior. Retain offline_docs paths and keys, then test restart, missing files, partial transfers, retry/delete races and local-copy removal.
- Phase-02 photo/session work is under validation. Full state art/motion/icon coverage and physical-device/accessibility performance gates remain open. Do not mark phase 02 complete or bypass blocking gates.
- Next implementation sequence after readiness gate: year-scoped resource landing and compact subjects; recursive mixed-folder mapping/breadcrumbs; real PDF thumbnails; search scopes; offline saved hierarchy/recovery. Preserve fallback routes throughout.
