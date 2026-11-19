"""Create an evidence-backed release report from validated CI artifacts."""
import json
import re
import shutil
import sys
from pathlib import Path

native_dir, output_dir, source, build_run, profile_run = sys.argv[1:]
assert re.fullmatch(r'[0-9a-f]{40}', source)
assert build_run.isdigit() and profile_run.isdigit()
output = Path(output_dir)
metrics_files = list(Path(native_dir).rglob('frame-timings.json'))
assert len(metrics_files) == 1, metrics_files
raw = json.loads(metrics_files[0].read_text())
scenarios = ['tab_navigation', 'home_scroll', 'route_transitions', 'pdf_open']
metrics = {name: raw[name] for name in scenarios}
rows = []
for name, values in metrics.items():
    assert values['frame_count'] > 0, name
    rows.append('| {} | {} | {:.2f} | {:.2f} | {} | {} |'.format(
        name, values['frame_count'],
        values['90th_percentile_frame_build_time_millis'],
        values['90th_percentile_frame_rasterizer_time_millis'],
        values['missed_frame_build_budget_count'],
        values['missed_frame_rasterizer_budget_count']))
(output / 'profile-skia-software.json').write_text(json.dumps(metrics, indent=2) + '\n')
checksums = (output / 'SHA256SUMS.txt').read_text().strip()
metadata = (output / 'apk-metadata.txt').read_text().splitlines()[0]
logs = Path('install-validation')
seed = (logs / 'update-seed.txt').read_text()
update = (logs / 'update-verify.txt').read_text()
native_tests = (logs / 'native-pdf-tests.txt').read_text()
assert re.search(r'OK \(1 test\)', seed)
assert re.search(r'OK \(1 test\)', update)
passed = re.search(r'OK \((\d+) tests?\)', native_tests)
assert passed and 'FAILURES' not in native_tests
for name in ['update-seed.txt', 'update-verify.txt', 'native-pdf-tests.txt']:
    shutil.copyfile(logs / name, output / name)
report = f'''# 1.5.6+15 validation — Pastel Reference Edition

Application source: `{source}`. Publication verifies that production Flutter code,
Android code, assets and dependency manifests still match the signed build.

- Signed build, upgrade/startup and native document checks: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/{build_run}
- Actual native profile run: https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/{profile_run}
- Analyzer clean; all 156 Flutter regression/widget tests passed in the build.
- {passed.group(1)} native scanner/PDF/document tests passed.
- Installed production 1.5.5, seeded isolated preference/private-file sentinels,
  installed 1.5.6 with the same signing key and verified both sentinels survived.
- Signed application started successfully on the API 35 x86_64 emulator.
- Package/version, checksum, original signing certificate and ARM32/ARM64/x86_64
  libraries were verified. The existing backend and package ID are preserved.
- Actual Flutter captures cover Home, Study, Office, Downloads, Profile, Settings,
  Goals, Admin and onboarding/auth. The responsive suite covers 320/360/390/430/768dp,
  landscape, 1x/2x text and legacy dark preferences. The product remains light-only.
- Additional review: 12 Flutter web captures, five real tab navigation checks and
  no browser exceptions/overflows; admin management routes passed at 320dp/200% text.
- A rendered-date regression verifies two-digit week dates stay on one line at
  320dp/200% text. Image assets use constrained decoding; backgrounds are static.

## Native frame timing

API 35 Pixel 2 x86_64 emulator, Flutter 3.35.4 **profile mode**, Skia software
rendering. Values are milliseconds; the 60 Hz budget is about 16.7ms. Capture
readback runs after the performance windows. These are warm interaction samples,
with isolated sample data and a real generated PDF, not live account/load tests.

| Scenario | Frames | UI p90 ms | Raster p90 ms | UI over budget | Raster over budget |
| --- | ---: | ---: | ---: | ---: | ---: |
{chr(10).join(rows)}

**60 FPS is not verified.** Software rasterization exceeds the frame budget in
these samples. This emulator has no physical device GPU; production renderer
settings are unchanged. The UI timings and functional checks do not establish
physical-device GPU smoothness. No guarantee of 60 FPS is made.

Physical GPU/cold-start frame timing, camera/OCR quality, battery/memory under
sustained load, large PDFs/libraries/downloads and live account/push delivery
still require device verification.

## Binary

`{metadata}`

SHA-256:

```text
{checksums}
```

Original certificate SHA-256:
`3fd902d131ae56d8de4792c9f5953759e2b375e32bcad8f57f7ef5c0ab887f83`
'''
(output / 'validation-1.5.6.md').write_text(report)
print('Generated release report from nonempty native samples and actual upgrade/native test logs')
