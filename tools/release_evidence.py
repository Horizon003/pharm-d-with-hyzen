#!/usr/bin/env python3
"""Record the built source and require the original owner's APK certificate."""
import argparse
import hashlib
import json
import re
from pathlib import Path

CERT = '3fd902d131ae56d8de4792c9f5953759e2b375e32bcad8f57f7ef5c0ab887f83'
def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def evidence(source, output, commit, version, build):
    assert re.fullmatch(r'[a-f0-9]{40}', commit), 'Invalid commit'
    assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version), 'Invalid version'
    assert build.isdigit() and int(build) > 11, 'Version code must exceed baseline'
    report=(output/'signing-report.txt').read_text().lower()
    certificates=re.findall(r'^(?:signer #\d+|v2 signer:) certificate sha-256 digest:\s*([a-f0-9]+)\s*$',report,re.M)
    assert certificates == [CERT], 'Unexpected release certificate'
    assembly=json.loads((source/'review_assembly_manifest.json').read_text())
    assert assembly['debug_tests'] is False, 'Debug assembly cannot be released'
    # The normalization is the same as CI; record actual post-normalization
    # source bytes as well as the pre-normalization input assembly manifest.
    paths=[p for root in ('lib','android/app/src','test') for p in (source/root).rglob('*') if p.is_file()]
    paths += [source/'pubspec.yaml',source/'pubspec.lock']
    result={'commit':commit,'version':version,'build':int(build),'certificate_sha256':CERT,
      'apk_sha256':digest(output/'PharmD-With-Hyzen.apk'),'assembly':assembly,
      'normalized_source_sha256':{p.relative_to(source).as_posix():digest(p) for p in sorted(paths)},
      'backend_deployed':False,'physical_device_acceptance':'not established by this workflow'}
    (output/'release-evidence.json').write_text(json.dumps(result,indent=2)+'\n')
    names=['PharmD-With-Hyzen.apk','release-evidence.json','signing-report.txt']
    (output/'SHA256SUMS').write_text(''.join(f'{digest(output/n)}  {n}\n' for n in names))
    (output/'release-notes.md').write_text(f'Android {version} ({build}), source `{commit}`.\n\nBuilt from the canonical source assembly including every current phase and scanner overlay. Original signing certificate verified. APK checksum and build provenance attached.\n\nBackend source is not deployed by this release workflow. Quiz availability requires separate verified backend configuration. Physical-device/live-account acceptance is not established by automated build checks.\n')
    return result
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('source','output','commit','version','build'):parser.add_argument('--'+name,required=True)
    a=parser.parse_args();evidence(Path(a.source),Path(a.output),a.commit,a.version,a.build)
