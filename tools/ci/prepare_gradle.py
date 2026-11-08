"""Stage the official, checksum-pinned Gradle runtime via its release API.

The distribution's browser redirect intermittently returns HTTP 504. The release
API supplies the same bytes; both this script and the wrapper verify the official
SHA-256. Only CI's temporary wrapper transport is changed, never Gradle's version.
"""
import hashlib
import os
from pathlib import Path
import time
import urllib.request

SHA256 = '20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78'
SIZE = 136983045
archive = Path(os.environ['RUNNER_TEMP']) / 'hyzen-gradle-8.13-bin.zip'
url = 'https://api.github.com/repos/gradle/gradle-distributions/releases/assets/232373824'
url += '?hyzen_build=' + os.environ.get('GITHUB_RUN_ID', 'manual')
for attempt in range(3):
    try:
        digest = hashlib.sha256()
        size = 0
        request = urllib.request.Request(url, headers={
            'Accept': 'application/octet-stream', 'User-Agent': 'Hyzen-CI'})
        with urllib.request.urlopen(request, timeout=60) as response, archive.open('wb') as output:
            if response.status != 200:
                raise ValueError('Incomplete Gradle response')
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                digest.update(chunk)
                size += len(chunk)
        if size != SIZE or digest.hexdigest() != SHA256:
            raise ValueError('Gradle size/checksum mismatch')
        break
    except Exception as error:
        archive.unlink(missing_ok=True)
        print(f'Gradle download attempt {attempt + 1}/3 failed: {getattr(error, "code", type(error).__name__)}', flush=True)
        if attempt == 2:
            raise RuntimeError('Verified Gradle runtime download is unavailable') from None
        time.sleep(5)
wrapper = Path(__file__).resolve().parents[2] / 'hyzen_flutter/android/gradle/wrapper/gradle-wrapper.properties'
lines = wrapper.read_text().splitlines()
if f'distributionSha256Sum={SHA256}' not in lines:
    raise ValueError('Wrapper checksum does not match the pinned official release')
wrapper.write_text('\n'.join('distributionUrl=' + archive.as_uri()
                            if line.startswith('distributionUrl=') else line
                            for line in lines) + '\n')
print('Official Gradle 8.13 runtime verified and staged', flush=True)
