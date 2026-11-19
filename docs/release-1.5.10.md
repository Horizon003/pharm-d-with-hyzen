# PHARM D WITH HYZEN 1.5.10+19 — Firebase & Admin Tools

Review build. Firebase rules and indexes are now deployed in the existing
`pharmawhisper-debd2` project. Authenticated production smoke checks passed for
claims, study credit, calendar privacy, ranking queries and opt-out. Temporary
QA users and their records were removed. No new APK or Blaze plan is needed.

- Deployment: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44441672939
- Live checks: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44442506765

- Study history, points, streak claims, calendar and professional ranks use direct
  Firestore SDK calls and Firebase Auth. No study requests use Cloudflare.
- Confirmed Firebase snapshots update points/calendar/rank. Personal offline
  history is preserved and queued for migration. Old backend data is not deleted.
- Admin bulk import accepts the previous website's CSV/JSON/XLSX templates,
  mixed workbook sheets, grouped JSON, Books/Slides/Special/MCQs/Papers/Lectures,
  past-paper inference and optional lecture filename/section. Valid rows can be
  imported while invalid/duplicate/conflicting lecture rows are excluded.
- Import history offers batch undo without deleting later additions.
- A 320dp/200% font dropdown overflow is fixed. CSV/JSON/Excel template downloads and JSON backup export/restore work through
  native Android document pickers and browser file/download APIs.
- Firebase ranking requires one-time consent through its existing privacy control, preserving legacy opt-out safety.
- Administrator verification changes atomically invalidate public ranking rows;
  validated private history is retained.

Production package ID and signing certificate retained. This is a versionCode 19
upgrade. Physical Infinix Note 8 verification, OEM notification delivery and physical GPU performance remain pending. No new physical GPU
frame-rate measurement or universal 60 FPS guarantee is claimed.

Legacy binary `.xls` is not supported: save it as `.xlsx` first. Pre-migration
Worker competitive scores are not promoted into verified Firebase scores from
untrusted client data. Existing local personal history is retained.
