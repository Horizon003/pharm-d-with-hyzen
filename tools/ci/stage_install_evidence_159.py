"""Attach verified upgrade/startup/native-test evidence to a reused signed build."""
import re
import shutil
import sys
from pathlib import Path

source, output, commit, build_run, profile_run = sys.argv[1:]
source, output = Path(source), Path(output)
assert re.fullmatch(r'[0-9a-f]{40}', commit)
assert build_run.isdigit() and profile_run.isdigit()
for name in ['update-seed.txt', 'update-verify.txt']:
    text = (source / name).read_text()
    assert re.search(r'OK \(1 test\)', text), name
native = (source / 'native-pdf-tests.txt').read_text()
passed = re.search(r'OK \((\d+) tests?\)', native)
assert passed and 'FAILURES' not in native
for name in ['update-seed.txt', 'update-verify.txt', 'native-pdf-tests.txt']:
    shutil.copyfile(source / name, output / name)
(output / 'validation-1.5.9.md').write_text(f'''# 1.5.9+18 validation

Signed application source: `{commit}`.

- Signed build, update/startup and {passed.group(1)} native document tests:
  https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/{build_run}
- Corrected native profile harness:
  https://github.com/Horizon003/pharm-d-with-hyzen/actions/runs/{profile_run}
- The signed source and measured source have identical production Dart, Android,
  assets and dependency manifests. Only the test harness/workflow changed.
- Existing preferences/private-file sentinels survived update from 1.5.8.
- APK checksum, original production certificate, package/version and
  ARM32/ARM64/x86_64 libraries were verified before publication.
- Cloudflare reward/calendar deployment and an authenticated production check
  remain pending; this package is a review prerelease, not the stable updater target.
- Raw measured frame data and the emulator limitations are in frame-timings.json
  and profile-summary.md. Physical Note 8 GPU/camera/Drive testing is pending.
''')
print('Verified install/data-retention evidence staged')
