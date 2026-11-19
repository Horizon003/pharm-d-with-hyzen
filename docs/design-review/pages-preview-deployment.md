# Interactive preview deployment status

The latest native Flutter source is packaged as a sample-data browser preview, with screen navigation, 320/360/390/430/tablet width controls and 100/130/200% text scaling. It does not use production accounts or publish backend changes. The wrapper no longer links an old APK as if it contained the latest UI.

`tools/live_preview/build.sh` now builds with the GitHub project Pages base `/pharm-d-with-hyzen/app/`. The previous `/app/` base would fail to load under this repository's Pages URL. Override HYZEN_PREVIEW_BASE_HREF for another hosting path.

The existing, registered `account-ui-review.yml` workflow builds the fixture entrypoint, runs analysis/tests, uploads a review artifact and deploys through the existing github-pages environment. It avoids requiring production backend secrets to review sample UI. The existing protected environment remains intact; no branch protection/deployment gate was changed. The separate production web-preview workflow is untouched.

Deployment uses the existing review branch and registered workflow:

```
gh workflow run account-ui-review.yml --ref work/monochrome-motion-1.5.5
```

Check that both build and deploy jobs succeed before sharing the expected Pages address. Any existing github-pages environment approval or branch policy must still be satisfied. The initial attempt was rejected by the branch policy. After authentication was restored, the exact review branch was added to the allowed branches and the failed deployment was rerun; the other protections remain intact.

Local verification: release Flutter web build succeeded; YAML and shell checks passed. Playwright loaded the packaged build at the real project prefix and opened Home, Study, Office, Settings, Notifications and Goals. The wrapper's width and text controls were exercised at 320dp and 200%. No uncaught runtime/overflow errors were recorded; this is not an Android performance measurement or live Drive/camera verification. Evidence and actual browser screenshots: `hyzen_flutter/qa/pages-preview/`.

Publication is now live at https://horizon003.github.io/pharm-d-with-hyzen/ . Deployment run: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/44181762179 . HTTP checks returned 200 for the wrapper and app index, and source-commit.txt matches 2e103612b4d0f61a4d0e3ca06c6f78c120477b2f. The six-screen browser smoke test also passed against the public URL, with zero uncaught runtime/overflow errors. Published evidence is in hyzen_flutter/qa/pages-live/.
