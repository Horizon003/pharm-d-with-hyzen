# Home actions and personal photo correction

Owner requested bold Study Library / Office Workspace titles, three circular 3D actions in the pink card, and restoration of their profile photo.

- Card titles now use Outfit 600.
- Pink bar order: Notes (`/study/notes`), Scan (`/create-pdf?source=camera`), Downloads (`/downloads`). Each visual circle is 40dp within a 48dp target. At narrow widths the Office column reserves enough width for all three targets; accessibility text still uses the existing stacked layout. Tooltips and screen-reader labels identify the actions.
- Three generated transparent pastel 3D assets live under `assets/reference/action-*.png`, decoded at120px for small controls. Originals remain in `/workspace/generated_images/`.
- Home and Office now resolve the saved valid HTTPS student photo first, then the authentication account photo. Profile/account views use the same resolution. Empty or retired avatar values show initials instead of substituting the Hyzen panda. Actual signed-in photo rendering still needs checking on the owner's device; fixture screenshots contain no uploaded photo.
- Daily Challenge Start begins/resumes the existing persisted session and pushes `/study-progress`, rather than the Study Library. Back returns Home while the study session continues. Goals remain available through the week ribbon and progress/statistics routes.

No backend, secrets, account record or data schema changed.

Validation: analyzer clean; full 164-test Flutter suite passed, including the responsive matrix, photo resolution/initials cases, 48dp quick-action targets, all three destinations and Daily Challenge session retention on Back. Eleven representative Flutter fixture screenshots were recaptured. Camera route uses a mocked platform channel in widget tests; physical-camera and signed-in photo checks remain device work. No new signed APK published in this refinement.
